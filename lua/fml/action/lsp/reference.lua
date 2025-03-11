local __module_name__ = "fml.action.lsp" ---@type string

local lsp = require("eve.builtin.lsp")
local path = require("eve.builtin.path")
local reporter = require("eve.builtin.reporter")
local editor = require("eve.module.editor")

local FileSelect = require("fml.ux.file_select")

---@param context                       eve.command.IContext
---@param method                        string
---@param additional_params             table<string, any>
---@param callback                      fun(ok: boolean, data: fml.ux.file_select.IData|nil): nil
---@see https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#referenceContext
local function fetch_data(context, method, additional_params, callback)
  local winnr = context.winnr ---@type integer
  local bufnr = context.bufnr ---@type integer
  if not editor.is_buf_valid(bufnr) or not editor.is_buf_sourcefile(bufnr) then
    return
  end

  if not editor.is_win_valid(winnr) or not editor.is_win_sourcefile(winnr) then
    return
  end

  if not lsp.has_support_method(bufnr, method) then
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

          for _, location in ipairs(locations) do
            ---@diagnostic disable-next-line: undefined-field
            local uri = location.targetUri or location.uri
            ---@diagnostic disable-next-line: undefined-field
            local range = location.targetRange or location.range
            if uri ~= nil and range ~= nil then
              local filepath = path.normalize(uri:gsub("^file://", "")) ---@type string
              local filepath_relative = path.relative(cwd, filepath, true) ---@type string
              local lnum = range.start.line + 1 ---@type integer
              local col = range.start.character ---@type integer

              local last_item = items[#items] ---@type fml.ux.file_select.IRawItem|nil
              if last_item == nil or last_item.filepath ~= filepath or last_item.lnum ~= lnum then
                local uuid = filepath .. ":" .. tostring(lnum) .. ":" .. tostring(col) ---@type string
                ---@type fml.ux.file_select.IRawItem
                local item = {
                  group = filepath,
                  filepath = filepath,
                  filepath_relative = filepath_relative,
                  uuid = uuid,
                  lnum = lnum,
                  col = col,
                }
                table.insert(items, item)
              end
            end
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

    if #items == 1 then
      local item = items[1] ---@type fml.ux.file_select.IRawItem
      editor.open_filepath(winnr, item.filepath, item.lnum, item.col)
      callback(true, nil)
      return
    end

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
    local data = { items = items, cwd = cwd } ---@type fml.ux.file_select.IData
    callback(true, data)
  end)
end

---@param title                         string
---@param method                        string
---@param additional_params             table<string, any>
---@return fun(context: eve.command.IContext): nil
local function create_jump_or_list(title, method, additional_params)
  local _last_data = { items = {}, cwd = path.cwd() } ---@type fml.ux.file_select.IData

  local select = nil ---@type fml.ux.IFileSelect|nil
  select = FileSelect.new({
    delay_fetch = 0,
    delay_render = 10,
    preview_enabled = true,
    extend_preset_keymaps = true,
    multiple = true,
    title = title,
    provider = {
      fetch_data = function()
        return _last_data
      end,
    },
  })

  ---@param context                     eve.command.IContext
  local function jump_or_list(context)
    fetch_data(context, method, additional_params, function(ok, data)
      if ok then
        if data ~= nil then
          _last_data = data

          if select ~= nil then
            select:mark_data_dirty()
            select:show()
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

---@param context                       eve.command.IContext
---@return nil
function M.goto_definitions(context)
  jump_or_lists.definitions(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_implementations(context)
  jump_or_lists.implementations(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_references(context)
  jump_or_lists.references(context)
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_type_definitions(context)
  jump_or_lists.type_definitions(context)
end

return M
