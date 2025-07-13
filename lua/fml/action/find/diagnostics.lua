---@diagnostic disable: invisible
local name = "fml.action.find.diagnostics" ---@type string
local title = "Find diagnostics" ---@type string

---@alias fml.action.find.diagnostics.SeverityEnum
---| "ERROR"
---| "WARN"
---| "INFO"
---| "HINT"

---@class fml.action.find.diagnostics.ILocationData
---@field public bufnr                  integer
---@field public diagnostic             vim.Diagnostic
---@field public severity               fml.action.find.diagnostics.SeverityEnum

local finder_input_history = std.InputHistory.new({ name = name, capacity = 5 })
local o_finder_input = std.Observable.from_value("")
local o_flag_foldempty = std.Observable.from_value(true)
local o_flag_fuzzy = std.Observable.from_value(false)
local o_flag_regex = std.Observable.from_value(false)
local o_flag_sensitive = std.Observable.from_value(false)
local o_flag_selected = std.Observable.from_value(false)
local o_flag_viewtype = std.Observable.from_value("tree")
local o_flag_severity = std.Observable.from_value(nil)

local _bufnr ---@type integer|nil
local picker ---@type eve.ux.picker.FiletreeComposer

---@param force                         boolean
---@return nil
local function refresh(force)
  if _bufnr ~= nil and vim.api.nvim_buf_is_valid(_bufnr) == false then
    std.reporter.error({
      from = name,
      subject = "refresh",
      message = "Buffer is not valid or not set.",
      details = {
        bufnr = _bufnr,
        force = force,
      },
    })
  end

  local filetree = picker._filetree ---@type std.collection.Filetree
  local treeview = picker._treeview ---@type eve.ux.picker.FiletreeView
  local flag_severity = o_flag_severity:snapshot() ---@type string
  local diagnostics = vim.diagnostic.get(_bufnr, { severity = flag_severity }) ---@type vim.Diagnostic[]

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

  local cwd = std.path.cwd() ---@type string

  filetree:clear()
  treeview:clear()

  local filepaths = {} ---@type string[]
  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      if filepaths[#filepaths] ~= filepath then
        filepaths[#filepaths + 1] = filepath
      end
    end
  end
  picker:reset_filepaths(cwd, filepaths, false)

  local statemap = treeview.statemap ---@type table<string, eve.ux.view.tree.INodeState>
  ---@cast statemap                     table<string, eve.ux.picker.view.filetree.INodeState>

  for _, diagnostic in ipairs(diagnostics) do
    local bufnr = diagnostic.bufnr
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
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

      local locationuuid =
        string.format("%s:%d:%d:%d#%d", filepath, diagnostic.lnum, diagnostic.col, diagnostic.end_col, #locations) ---@type string

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
        lnum = diagnostic.lnum,
        col = diagnostic.col,
        col_end = diagnostic.end_col or diagnostic.col,
        text = text,
        highlights = highlights,
      }
      locations[#locations + 1] = location
      statemap[locationuuid] = location
    end

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

  finder_input_history = finder_input_history,
  finder_input = o_finder_input,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
  flag_viewtype = o_flag_viewtype,
  flag_foldempty = o_flag_foldempty,
  flag_selected = o_flag_selected,

  on_refresh = function(_)
    refresh(false)
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_diagnostics()
  refresh(false)
  picker:focus()
end

return M
