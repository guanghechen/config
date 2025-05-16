local __module_name__ = "fml.action.lsp" ---@type string

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
              local filepath = eve.path.normalize(uri:gsub("^file://", "")) ---@type string
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
    local rootdir = eve.path.cwd() ---@type string
    for _, item in ipairs(items) do
      local filepath = string.format("%s:%d:%d", item[1], item[2], item[3]) ---@type string
      filepaths[#filepaths + 1] = filepath

      if filepath:sub(1, #rootdir) ~= rootdir then
        while true do
          local parent = eve.path.dirname(rootdir) ---@type string
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
---@return fun(): nil
local function create_jump_or_list(title, method, additional_params)
  local finder_input = std.Observable.from_value("")
  local flag_foldempty = std.Observable.from_value(true)
  local flag_fuzzy = std.Observable.from_value(false)
  local flag_regex = std.Observable.from_value(false)
  local flag_sensitive = std.Observable.from_value(true)
  local flag_viewtype = std.Observable.from_value("tree")

  local picker = eve.ux.FilePicker.new({
    name = string.format("lsp-reference:%s", method),
    permanent = true,
    title = title,
    height = 0.80,
    width = 0.85,

    finder_input = finder_input,
    finder_multiline = false,

    flag_foldempty = flag_foldempty,
    flag_fuzzy = flag_fuzzy,
    flag_regex = flag_regex,
    flag_sensitive = flag_sensitive,
    flag_viewtype = flag_viewtype,
    flags_start_index = 1,

    on_close = function()
      finder_input:next("")
    end,
  })

  local function jump_or_list()
    fetch_data(method, additional_params, function(ok, rootdir, filepaths)
      if ok and rootdir ~= nil and filepaths ~= nil then
        picker:reset_filepaths(rootdir, filepaths, true)
        picker:mark_result_dirty()
        picker:focus()
      end
    end)
  end
  return jump_or_list
end

local jump_or_lists = {
  references = create_jump_or_list(
    "LSP References",
    "textDocument/references",
    { context = { includeDeclaration = true } }
  ),
  definitions = create_jump_or_list("LSP Definitions", "textDocument/definition", {}),
  type_definitions = create_jump_or_list("LSP Type Definitions", "textDocument/typeDefinition", {}),
  implementations = create_jump_or_list("LSP Implementations", "textDocument/implementation", {}),
}

---@class fml.action.lsp
local M = {}

---@return nil
function M.goto_definitions()
  jump_or_lists.definitions()
end

---@return nil
function M.goto_implementations()
  jump_or_lists.implementations()
end

---@return nil
function M.goto_references()
  jump_or_lists.references()
end

---@return nil
function M.goto_type_definitions()
  jump_or_lists.type_definitions()
end

return M
