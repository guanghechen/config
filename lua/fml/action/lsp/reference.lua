local __module_name__ = "fml.action.lsp" ---@type string

local checks = require("eve.lib.checks")
local lsp = require("eve.lib.lsp")
local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local state = require("eve.state")
local FileSelect = require("fml.ux.file_select")

---@param method                        string
---@param additional_params             table<string, any>
---@param callback                      fun(ok: boolean, data: fml.ux.file_select.IData|nil): nil
---@see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#referenceContext
local function fetch_data(method, additional_params, callback)
  local winnr = state.tab.get_current_winnr() or 0 ---@type integer
  local bufnr = winnr > 0 and vim.api.nvim_win_get_buf(winnr) or 0 ---@type integer
  if not checks.is_buf_valid(bufnr) or not lsp.has_support_method(bufnr, method) then
    reporter.error({
      from = __module_name__,
      subject = "fetch_data",
      message = "Not support method.",
      details = { bufnr = bufnr, method = method, context = additional_params },
    })
    callback(false, nil)
    return
  end

  local cwd = path.cwd() ---@type string
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

          local raw_items = vim.lsp.util.locations_to_items(locations, offset_encoding)
          for _, raw_item in ipairs(raw_items) do
            local filepath = path.relative(cwd, raw_item.filename, true) ---@type string
            local lnum = raw_item.lnum ---@type integer
            local col = raw_item.col - 1 ---@type integer
            local uuid = filepath .. ":" .. tostring(lnum) .. ":" .. tostring(col) ---@type string

            ---@type fml.ux.file_select.IRawItem
            local item = { group = filepath, filepath = filepath, uuid = uuid, lnum = lnum, col = col }
            table.insert(items, item)
          end
        end
      end
    end

    if #errors > 0 then
      reporter.error({
        from = __module_name__,
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

    if #items > 1 then
      table.sort(items, function(a, b)
        if a.filepath == b.filepath then
          if a.lnum == b.lnum then
            return a.col < b.col
          end
          return a.lnum < b.lnum
        end
        return a.filepath < b.filepath
      end)

      local k = 1 ---@type integer
      local last_item = items[k] ---@type fml.ux.file_select.IRawItem
      local N = #items ---@type integer
      for i = 2, N, 1 do
        local item = items[i] ---@type fml.ux.file_select.IRawItem

        if item.filepath ~= last_item.filepath or item.lnum ~= last_item.lnum then
          k = k + 1
          items[k] = item
          last_item = item
        end
      end
      for i = k + 1, N, 1 do
        items[i] = nil
      end
    end

    if #items == 1 and first_location ~= nil then
      vim.lsp.util.jump_to_location(first_location, first_encoding, false)
      callback(true, nil)
      return
    end

    ---@type fml.ux.file_select.IData
    local data = { items = items, cwd = cwd }
    callback(true, data)
  end)
end

---@param title                         string
---@param method                        string
---@param additional_params             table<string, any>
---@return fun(): nil
local function create_jump_or_list(title, method, additional_params)
  local _last_data = { items = {}, cwd = path.cwd() } ---@type fml.ux.file_select.IData

  local select = nil ---@type fml.ux.IFileSelect|nil
  select = FileSelect.new({
    delay_fetch = 0,
    delay_render = 10,
    preview_enabled = true,
    extend_preset_keymaps = true,
    title = title,
    provider = {
      fetch_data = function()
        return _last_data
      end,
    },
  })

  local function jump_or_list()
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
