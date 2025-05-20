local __module_name__ = "fml.action.lsp.reference" ---@type string

local finder_input = std.Observable.from_value("")
local flag_foldempty = eve.context.select.lsp_reference.flag_foldempty
local flag_fuzzy = eve.context.select.lsp_reference.flag_fuzzy
local flag_regex = eve.context.select.lsp_reference.flag_regex
local flag_sensitive = eve.context.select.lsp_reference.flag_case_sensitive
local flag_selected = eve.context.select.lsp_reference.flag_selected
local flag_viewtype = eve.context.select.lsp_reference.flag_viewtype

local picker = eve.ux.FilePicker.new({
  name = "lsp:reference",
  permanent = true,
  title = "LSP References",
  height = 0.80,
  width = 0.85,

  finder_input = finder_input,
  finder_multiline = false,

  flag_foldempty = flag_foldempty,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,
  flag_selected = flag_selected,
  flag_viewtype = flag_viewtype,
  flags_start_index = 1,

  on_close = function()
    finder_input:next("")
  end,
})

---@param method                        string
---@param additional_params             table<string, any>
---@param callback                      fun(ok: boolean, rootdir: string|nil, filepaths: string[]|nil): nil
---@see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#referenceContext
local function fetch_data(method, additional_params, callback)
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
  if winnr_sourcefile == nil then
    callback(false)
    return
  end

  local bufnr_sourcefile = vim.api.nvim_win_get_buf(winnr_sourcefile) ---@type integer
  if not eve.lsp.has_support_method(bufnr_sourcefile, method) then
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
    local items = {} ---@type [string, integer, integer][]

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
                table.insert(locations, location)
              end
            end
          else
            local location = result
            local uri = location.targetUri or location.uri
            local range = location.targetRange or location.range
            if uri ~= uri_cur or range.start.line ~= line_cur then
              table.insert(locations, location)
            end
          end

          for _, location in ipairs(locations) do
            ---@diagnostic disable-next-line: undefined-field
            local uri = location.targetUri or location.uri
            ---@diagnostic disable-next-line: undefined-field
            local range = location.targetRange or location.range
            if uri ~= nil and range ~= nil then
              local filepath = std.path.normalize(uri:gsub("^file://", "")) ---@type string
              local lnum = range.start.line + 1 ---@type integer
              local col = range.start.character ---@type integer
              local last_item = items[#items] ---@type [string, integer, integer]|nil
              if last_item == nil or last_item[1] ~= filepath or last_item[2] ~= lnum then
                local item = { filepath, lnum, col } ---@type [string, integer, integer]
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
      callback(true)
      return
    end

    if #items == 1 then
      local filepath, lnum, col = unpack(items[1]) ---@type string, integer, integer
      eve.win.open_filepath(winnr_sourcefile, filepath, lnum, col)
      callback(true)
      return
    end

    local filepaths = {} ---@type string[]
    local rootdir = std.path.cwd() ---@type string
    for _, item in ipairs(items) do
      local filepath = string.format("%s:%d:%d", item[1], item[2], item[3]) ---@type string
      filepaths[#filepaths + 1] = filepath

      if filepath:sub(1, #rootdir) ~= rootdir then
        while true do
          local parent = std.path.dirname(rootdir) ---@type string
          if parent == rootdir then
            break
          end
          rootdir = parent
        end
      end
    end
    callback(true, rootdir, filepaths)
  end)
end

---@param title                         string
---@param method                        string
---@param additional_params             table<string, any>
---@return nil
local function focus(title, method, additional_params)
  fetch_data(method, additional_params, function(ok, rootdir, filepaths)
    if ok and rootdir ~= nil and filepaths ~= nil then
      picker.finder:set_title(title)
      picker:reset_filepaths(rootdir, filepaths, true)
      picker:mark_result_dirty()
      picker:focus()
    end
  end)
end

---@class fml.action.lsp
local M = {}

---@return nil
function M.goto_definitions()
  focus("LSP Definitions", "textDocument/definition", {})
end

---@return nil
function M.goto_implementations()
  focus("LSP Implementations", "textDocument/implementation", {})
end

---@return nil
function M.goto_references()
  focus("LSP References", "textDocument/references", { context = { includeDeclaration = true } })
end

---@return nil
function M.goto_type_definitions()
  focus("LSP Type Definitions", "textDocument/typeDefinition", {})
end

return M
