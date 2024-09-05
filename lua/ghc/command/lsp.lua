---@param method                        string
---@param additional_params             table<string, any>
---@param callback                      fun(ok: boolean, data: fml.types.ui.file_select.IData|nil): nil
---@see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#referenceContext
local function fetch_data(method, additional_params, callback)
  local bufnr = eve.globals.widgets.get_current_bufnr() or vim.api.nvim_get_current_buf() ---@type integer
  if not eve.lsp.has_support_method(bufnr, method) then
    eve.reporter.error({
      from = "ghc.command.lsp",
      subject = "fetch_data",
      message = "Not support method.",
      details = { bufnr = bufnr, method = method, context = additional_params },
    })
    callback(false, nil)
    return
  end

  local cwd = eve.path.cwd() ---@type string
  local winnr = fml.api.state.get_current_tab_winnr() ---@type integer
  local params = vim.tbl_extend("force", vim.lsp.util.make_position_params(winnr), additional_params)

  vim.lsp.buf_request_all(bufnr, method, params, function(results_per_client)
    local items = {}
    local first_encoding = nil ---@type string|nil
    local first_location = nil ---@type lsp.Location|nil
    local errors = {} ---@type string[]

    local uri_cur = params.textDocument.uri ---@type string
    local line_cur = params.position.line ---@type integer
    for client_id, result_or_error in pairs(results_per_client) do
      local error, result = result_or_error.error, result_or_error.result
      if error then
        local details = "Failed to executing '" .. method .. "' (" .. client_id .. "): " .. error.message
        table.insert(errors, details)
      else
        if result ~= nil then
          local locations = {} ---@type lsp.Location[]
          if vim.islist(result) then
            for _, location in ipairs(result) do
              if location.uri ~= uri_cur or location.range.start.line ~= line_cur then
                table.insert(locations, location)
              end
            end
          else
            local location = result ---@type lsp.Location
            if location.uri ~= uri_cur or location.range.start.line ~= line_cur then
              table.insert(locations, location)
            end
          end

          local offset_encoding = vim.lsp.get_client_by_id(client_id).offset_encoding
          if first_encoding == nil and #locations > 0 then
            first_encoding = offset_encoding
            first_location = locations[1]
          end

          for _, raw_item in ipairs(vim.lsp.util.locations_to_items(locations, offset_encoding)) do
            ---@type fml.types.ui.file_select.IRawItem
            local item = {
              filepath = eve.path.relative(cwd, raw_item.filename, true),
              lnum = raw_item.lnum,
              col = raw_item.col,
            }
            table.insert(items, item)
          end
        end
      end
    end

    if #errors > 0 then
      eve.reporter.error({
        from = "ghc.command.lsp",
        subject = "fetch_data",
        message = "Encountered errors.",
        details = { bufnr = bufnr, method = method, params = params, errors = errors },
      })
      callback(false, nil)
      return
    end

    if #items <= 0 then
      callback(true, nil)
      return
    end

    if #items == 1 and first_location ~= nil then
      vim.lsp.util.jump_to_location(first_location, first_encoding, false)
      callback(true, nil)
      return
    end

    ---@type fml.types.ui.file_select.IData
    local data = { items = items, cwd = cwd }
    callback(true, data)
  end)
end

---@param title                         string
---@param method                        string
---@param additional_params             table<string, any>
---@return fun(): nil
local function create_select(title, method, additional_params)
  local _last_data = { items = {}, cwd = eve.path.cwd() } ---@type fml.types.ui.file_select.IData

  local select = nil ---@type fml.types.ui.IFileSelect|nil
  select = fml.ui.FileSelect.new({
    delay_fetch = 10,
    delay_render = 10,
    destroy_on_close = true,
    enable_preview = true,
    extend_preset_keymaps = true,
    title = title,
    provider = {
      fetch_data = function()
        return _last_data
      end,
    },
  })

  local function fetch()
    fetch_data(method, additional_params, function(ok, data)
      if ok then
        if data ~= nil then
          _last_data = data

          if select ~= nil then
            select:mark_data_dirty()
            select:focus()
          end
        end
      end
    end)
  end
  return fetch
end

local selects = {
  reference = create_select("LSP Reference", "textDocument/references", { context = { includeDeclaration = true } }),
}

---@class  ghc.command.lsp
local M = {}

---@return nil
function M.find_reference()
  selects.reference()
end

vim.keymap.set({ "i", "n", "v", "t" }, "<F8>", M.find_reference, {
  desc = "lsp: find references",
  noremap = true,
  silent = true,
  nowait = true,
})

return M
