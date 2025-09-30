---@diagnostic disable: invisible
local __module_name__ = "fml.action.lsp.reference" ---@type string

local Methods = vim.lsp.protocol.Methods

---@class fml.action.lsp.reference.IItem
---@field public filepath               string
---@field public lnum                   integer
---@field public col                    integer
---@field public col_end                integer

local finder_input = std.Observable.from_value("")
local flag_foldempty = eve.context.select.lsp_reference.flag_foldempty
local flag_fuzzy = eve.context.select.lsp_reference.flag_fuzzy
local flag_regex = eve.context.select.lsp_reference.flag_regex
local flag_case_sensitive = eve.context.select.lsp_reference.flag_case_sensitive
local flag_selected = eve.context.select.lsp_reference.flag_selected
local flag_viewtype = eve.context.select.lsp_reference.flag_viewtype

local picker = eve.ux.picker.FiletreeComposer.new({
  name = "lsp:reference",
  permanent = true,
  frecency = eve.context.frecency.files,
  title = "LSP References",
  height = 0.80,
  width = 0.85,

  finder_input = finder_input,

  flag_foldempty = flag_foldempty,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_case_sensitive = flag_case_sensitive,
  flag_selected = flag_selected,
  flag_viewtype = flag_viewtype,
  flags_start_index = 1,

  on_close = function()
    finder_input:next("")
  end,
})

---@param method                        string
---@param buf_flagname                  string
---@param additional_params             table<string, any>
---@param callback                      fun(ok: boolean, items: fml.action.lsp.reference.IItem[]|nil): nil
---@see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#referenceContext
local function fetch_data(method, buf_flagname, additional_params, callback)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile == nil then
    callback(false)
    return
  end

  local bufnr_sourcefile = vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
  if not vim.b[bufnr_sourcefile][buf_flagname] then
    std.reporter.error({
      from = __module_name__,
      subject = "fetch_data",
      message = "Not support method.",
      details = { bufnr = bufnr_sourcefile, method = method, context = additional_params },
    })
    callback(false)
    return
  end

  local params =
    vim.tbl_extend("force", vim.lsp.util.make_position_params(winnr_sourcefile, "utf-8"), additional_params)

  vim.lsp.buf_request_all(bufnr_sourcefile, method, params, function(results_per_client)
    local errors = {} ---@type string[]
    local items = {} ---@type fml.action.lsp.reference.IItem[]

    local uri_cur = params.textDocument.uri ---@type string
    local line_cur = params.position.line ---@type integer
    for client_id, result_or_error in pairs(results_per_client) do
      local error, result = result_or_error.err, result_or_error.result
      if error then
        local details = "Failed to executing '" .. method .. "' (" .. client_id .. "): " .. error.message
        table.insert(errors, details)
      else
        if result ~= nil then
          local locations = {} ---@type lsp.Location[]
          if vim.islist(result) then
            for _, location in ipairs(result) do
              local uri = location.targetUri or location.uri
              local range = location.targetRange or location.range
              if uri ~= uri_cur or range.start.line ~= line_cur then
                locations[#locations + 1] = location
              end
            end
          else
            local location = result
            local uri = location.targetUri or location.uri
            local range = location.targetRange or location.range
            if uri ~= uri_cur or range.start.line ~= line_cur then
              locations[#locations + 1] = location
            end
          end

          for _, location in ipairs(locations) do
            ---@diagnostic disable-next-line: undefined-field
            local uri = location.targetUri or location.uri
            ---@diagnostic disable-next-line: undefined-field
            local range = location.targetRange or location.range
            if uri ~= nil and range ~= nil then
              local filepath = std.path.normalize(vim.uri_to_fname(uri)) ---@type string
              local lnum = range.start.line + 1 ---@type integer
              local col = range.start.character ---@type integer
              local last_item = items[#items] ---@type fml.action.lsp.reference.IItem|nil
              if last_item == nil or last_item.filepath ~= filepath or last_item.lnum ~= lnum then
                local lnum_end = range["end"].line + 1 ---@type integer

                ---@type fml.action.lsp.reference.IItem
                local item = {
                  filepath = filepath,
                  lnum = lnum,
                  col = col,
                  col_end = lnum == lnum_end and range["end"].character or -1,
                }
                items[#items + 1] = item
              end
            end
          end
        end
      end
    end

    if #errors > 0 then
      std.reporter.error({
        from = __module_name__,
        subject = "fetch_data",
        message = "Encountered errors.",
        details = { bufnr = bufnr_sourcefile, method = method, params = params, errors = errors },
      })
      callback(false)
      return
    end

    if #items <= 0 then
      callback(true, {})
      return
    end

    if #items == 1 then
      local item = items[1] ---@type fml.action.lsp.reference.IItem
      eve.win.open_filepath(winnr_sourcefile, item.filepath, item.lnum, item.col)
      callback(true, { item })
      return
    end

    callback(true, items)
  end)
end

---@param title                         string
---@param method                        string
---@param buf_flagname                  string
---@param additional_params             table<string, any>
---@return nil
local function focus(title, method, buf_flagname, additional_params)
  fetch_data(method, buf_flagname, additional_params, function(ok, items)
    if not ok or items == nil then
      return
    end

    if #items <= 0 then
      std.reporter.info({
        from = __module_name__,
        subject = title,
        message = "No items found.",
        details = { title = title, method = method, buf_flagname = buf_flagname, additional_params = additional_params },
      })
      return
    end

    if #items == 1 then
      return
    end

    local rootdir = std.path.cwd() ---@type string
    local filepaths = {} ---@type string[]
    for _, item in ipairs(items) do
      local filepath = string.format("%s:%d:%d:%d", item.filepath, item.lnum, item.col, item.col_end) ---@type string
      filepaths[#filepaths + 1] = filepath

      if string.sub(filepath, 1, #rootdir) ~= rootdir then
        while true do
          local parent = std.path.dirname(rootdir) ---@type string
          if parent == rootdir then
            break
          end
          rootdir = parent
        end
      end
    end

    picker.finder:set_title(title)
    picker:reset_filepaths(rootdir, filepaths, true)
    picker:mark_result_dirty()
    picker:focus()

    vim.schedule(function()
      local treeview = picker._treeview ---@type eve.ux.picker.FiletreeView
      treeview:traverse_filenode(nil, function(node, nodestate)
        if nodestate ~= nil and nodestate.locations ~= nil then
          local locations = nodestate.locations ---@type eve.ux.picker.view.filetree.ILocationNodeState[]
          local lnum_maximum = 1 ---@type integer
          for _, location in ipairs(locations) do
            lnum_maximum = lnum_maximum < location.lnum and location.lnum or lnum_maximum
          end

          local lines = vim.fn.readfile(node.data.filepath, "", lnum_maximum) ---@type string[]
          for _, location in ipairs(locations) do
            local line = lines[location.lnum] or "" ---@type string
            location.text = line
            location.highlights = { { coll = location.col, colr = location.col_end, hlname = "f_ft_reference" } }
          end
        end
      end)

      treeview:mark_cache_treeview_dirty()
      picker:mark_result_dirty()
    end)
  end)
end

---@class fml.action.lsp
local M = {}

---@return nil
function M.goto_definitions()
  focus("LSP Definitions", Methods.textDocument_definition, "support_definition", {})
end

---@return nil
function M.goto_implementations()
  focus("LSP Implementations", Methods.textDocument_implementation, "support_implementation", {})
end

---@return nil
function M.goto_references()
  focus(
    "LSP References",
    Methods.textDocument_references,
    "support_references",
    { context = { includeDeclaration = true } }
  )
end

---@return nil
function M.goto_type_definitions()
  focus("LSP Type Definitions", Methods.textDocument_typeDefinition, "support_typeDefinition", {})
end

return M
