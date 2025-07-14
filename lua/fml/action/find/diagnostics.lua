---@diagnostic disable: invisible

---@alias fml.action.find.diagnostics.SeverityEnum
---| "ERROR"
---| "WARN"
---| "INFO"
---| "HINT"

---@class fml.action.find.diagnostics.ILocationData
---@field public bufnr                  integer
---@field public diagnostic             vim.Diagnostic
---@field public severity               fml.action.find.diagnostics.SeverityEnum

local severity2prefixicon = eve.constant.diagnostic.severity2prefixicon ---@type table<vim.diagnostic.Severity, string> {
local severity2texticon = eve.constant.diagnostic.severity2texticon ---@type table<vim.diagnostic.Severity, string>
local severity2numhl = eve.constant.diagnostic.severity2numhl ---@type table<vim.diagnostic.Severity, string>

local name = "fml.action.find.diagnostics" ---@type string
local title = "Find diagnostics" ---@type string

local finder_input_history = std.InputHistory.new({ name = name, capacity = 5 })
local o_finder_input = std.Observable.from_value("")
local o_bufnr_sourcefile = std.Observable.from_value(nil)
local o_rootpath = std.Observable.from_value(std.path.cwd())
local o_flag_buffer = std.Observable.from_value(false)
local o_flag_foldempty = std.Observable.from_value(true)
local o_flag_fuzzy = std.Observable.from_value(false)
local o_flag_regex = std.Observable.from_value(false)
local o_flag_sensitive = std.Observable.from_value(false)
local o_flag_selected = std.Observable.from_value(false)
local o_flag_viewtype = std.Observable.from_value("tree")
local o_flag_severity = std.Observable.from_value(nil)

local picker ---@type eve.ux.picker.FiletreeComposer

---@param force                         boolean
---@return nil
local function refresh(force)
  local bufnr_sourcefile = nil ---@type integer|nil
  if o_flag_buffer:snapshot() then
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    bufnr_sourcefile = eve.tab.retrieve_bufnr_sourcefile(tabnr) ---@type integer|nil
    o_bufnr_sourcefile:next(bufnr_sourcefile)
  end

  if bufnr_sourcefile ~= nil and not vim.api.nvim_buf_is_valid(bufnr_sourcefile) then
    std.reporter.error({
      from = name,
      subject = "refresh",
      message = "Buffer is not valid or not set.",
      details = {
        bufnr_sourcefile = bufnr_sourcefile,
        force = force,
      },
    })
    return
  end

  local filetree = picker._filetree ---@type std.collection.Filetree
  local treeview = picker._treeview ---@type eve.ux.picker.FiletreeView
  local rootpath = o_rootpath:snapshot() ---@type string

  if bufnr_sourcefile ~= nil then
    local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
    if not std.path.is_under(rootpath, filepath) then
      rootpath = std.path.dirname(filepath) ---@type string
      o_rootpath:next(rootpath)
    end
  end

  local flag_severity = o_flag_severity:snapshot() ---@type string
  local original_diagnostics = vim.diagnostic.get(bufnr_sourcefile, { severity = flag_severity }) ---@type vim.Diagnostic[]

  local diagnostics = {} ---@type vim.Diagnostic[]
  local filepaths = {} ---@type string[]

  if bufnr_sourcefile ~= nil then
    local filepath = vim.api.nvim_buf_get_name(bufnr_sourcefile) ---@type string
    if vim.bo[bufnr_sourcefile].buftype == "" and #filepath ~= 0 then
      for _, diagnostic in ipairs(original_diagnostics) do
        if diagnostic.bufnr == bufnr_sourcefile then
          diagnostics[#diagnostics + 1] = diagnostic
          filepaths[#filepaths + 1] = filepath
        end
      end
    end

    table.sort(diagnostics, function(a, b)
      return a.lnum < b.lnum or (a.lnum == b.lnum and a.col < b.col)
    end)
  else
    for _, diagnostic in ipairs(original_diagnostics) do
      local bufnr = diagnostic.bufnr
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
        local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
        if filepath ~= "" and std.path.is_under(rootpath, filepath) then
          diagnostics[#diagnostics + 1] = diagnostic
          filepaths[#filepaths + 1] = filepath
        end
      end
    end

    table.sort(diagnostics, function(a, b)
      if a.bufnr == b.bufnr then
        return a.lnum < b.lnum or (a.lnum == b.lnum and a.col < b.col)
      end

      local a_filepath = vim.api.nvim_buf_get_name(a.bufnr) ---@type string
      local b_filepath = vim.api.nvim_buf_get_name(b.bufnr) ---@type string
      if a_filepath == b_filepath then
        return a.lnum < b.lnum or (a.lnum == b.lnum and a.col < b.col)
      end
      return a_filepath < b_filepath
    end)
  end

  filetree:clear()
  treeview:clear()

  picker:reset_filepaths(rootpath, filepaths, false)

  local statemap = treeview.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr
    ---@cast bufnr                      integer

    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local severity = diagnostic.severity
    severity = type(severity) == "number" and vim.diagnostic.severity[severity] or severity
    ---@cast severity                 fml.action.find.diagnostics.SeverityEnum

    local leafuuid = std.Filetree.uuid(filepath) ---@type string
    local leafnodestate = statemap[leafuuid] ---@type eve.ux.picker.view.filetree.INodeState|nil
    if leafnodestate == nil then
      goto continue
    end

    if leafnodestate.nodetype ~= "leaf" then
      std.reporter.error({
        from = picker.fullname,
        subject = "refresh",
        message = "Expected leaf node state, but got: " .. leafnodestate.nodetype,
        details = {
          filepath = filepath,
          nodetype = leafnodestate.nodetype,
        },
      })
      goto continue
    end

    local locations = leafnodestate.locations or {} ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
    leafnodestate.locations = locations

    ---@type fml.action.find.diagnostics.ILocationData
    local data = {
      bufnr = bufnr,
      diagnostic = diagnostic,
      severity = severity,
    }

    local locationuuid = string.format("%s:%d:%d:%d#%d", filepath, diagnostic.lnum, diagnostic.col, diagnostic.end_col, #locations) ---@type string

    local text ---@type string
    local highlights = {} ---@type std.t.IHighlightInline[]

    if diagnostic.code == nil then
      text = string.format("%s  : %s", eve.icon.diagnostic[severity], diagnostic.message) ---@type string
      highlights[#highlights + 1] = {
        coll = 0,
        colr = #eve.icon.diagnostic[severity],
        hlname = string.format("Diagnostic_%s", severity),
      }
    else
      text = string.format("%s %s : %s", eve.icon.diagnostic[severity], tostring(diagnostic.code), diagnostic.message) ---@type string
      highlights[#highlights + 1] = {
        coll = 0,
        colr = #eve.icon.diagnostic[severity],
        hlname = string.format("Diagnostic_%s", severity),
      }
    end

    ---@class eve.ux.picker.view.filetree.ILocationNodeState
    local location = {
      nodetype = "location",
      leafuuid = leafuuid,
      locationuuid = locationuuid,
      tick_invisible = 0,
      data = data,
      lnum = diagnostic.lnum + 1,
      col = diagnostic.col,
      col_end = diagnostic.end_col or diagnostic.col,
      text = text,
      highlights = highlights,
    }
    locations[#locations + 1] = location
    statemap[locationuuid] = location

    ::continue::
  end
end

picker = eve.ux.picker.FiletreeComposer.new({
  name = name,
  permanent = true,
  title = title,
  height = 0.9,
  width = 0.9,
  preview = true,

  keymaps_common = {
    {
      modes = { "n", "v" },
      key = "tc",
      desc = string.format("%s: change root (cwd)", title),
      callback = function()
        local cwd = std.path.cwd() ---@type string
        o_rootpath:next(cwd)
        refresh(false)
      end,
    },
    {
      modes = { "n", "v" },
      key = "tw",
      desc = string.format("%s: change root (workspace)", title),
      callback = function()
        local workspace = std.path.workspace() ---@type string
        o_rootpath:next(workspace)
        refresh(false)
      end,
    },
  },

  finder_input_history = finder_input_history,
  finder_input = o_finder_input,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
  flag_viewtype = o_flag_viewtype,
  flag_foldempty = o_flag_foldempty,
  flag_selected = o_flag_selected,

  flags_append = {
    {
      desc = string.format("%s: buffer only", name),
      callback = function()
        local enabled = o_flag_buffer:snapshot() ---@type boolean
        o_flag_buffer:next(not enabled)
      end,
      snapshot = function()
        local enabled = o_flag_buffer:snapshot() ---@type boolean
        return eve.icon.symbols.flag_buffer, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
  },

  on_attached = function(_, rootpath)
    o_rootpath:next(rootpath)
  end,

  on_refresh = function(_)
    refresh(false)
  end,

  on_preview_rendered = function(_, bufnr)
    local filenode = picker:__retrieve_filenode__() ---@type std.collection.filetree.INode|nil
    if filenode == nil then
      return
    end

    local bufnr_sourcefile = eve.buf.loadfile(filenode.data.filepath) ---@type integer|nil)
    if bufnr_sourcefile == nil then
      return
    end

    local diagnostics = vim.diagnostic.get(bufnr_sourcefile) ---@type vim.Diagnostic[]
    vim.diagnostic.set(eve.var.nsnr.diagnostic, bufnr, diagnostics, {
      virtual_text = false,
      virtual_lines = {
        format = function(diagnostic)
          local icon = severity2prefixicon[diagnostic.severity] or ""
          return string.format("%s %s", icon, diagnostic.message)
        end,
      },
      signs = {
        text = severity2texticon,
        numhl = severity2numhl,
      },
      severity_sort = true,
      underline = true,
      update_in_insert = false,
      float = {
        focus = true,
        focusable = true,
        border = "rounded",
      },
    })
  end,
})

std.fn.observe({ o_rootpath, o_bufnr_sourcefile, o_flag_buffer }, function()
  local cwd = std.path.cwd() ---@type string
  local flag_buffer = o_flag_buffer:snapshot() ---@type boolean
  if flag_buffer then
    local bufnr = o_bufnr_sourcefile:snapshot() ---@type integer|nil
    if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local relpath = std.path.relative(cwd, filepath, false) ---@type string
      picker.finder:set_title(string.format("%s (%s)", title, relpath))
      return
    end
  end

  local rootpath = o_rootpath:snapshot() ---@type string
  local workspace = std.path.workspace() ---@type string
  if rootpath == workspace then
    picker.finder:set_title(string.format("%s (workspace)", title))
  elseif rootpath == cwd then
    picker.finder:set_title(string.format("%s (cwd)", title))
  else
    local relative_path = std.path.is_under(workspace, rootpath) and std.path.relative(cwd, rootpath, false) or rootpath ---@type string
    picker.finder:set_title(string.format("%s (%s)", title, relative_path))
  end
end)

std.fn.observe({ o_flag_buffer }, function()
  picker:mark_result_flags_dirty()
  refresh(false)
end, true)



---@class fml.action.find
local M = {}

---@return nil
function M.find_diagnostics()
  refresh(false)
  picker:focus()
end

return M
