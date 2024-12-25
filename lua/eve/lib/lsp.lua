local augroup = require("eve.lib.nvim").augroup

---@class eve.lib.lsp.ISymbolPos
---@field public line                   integer
---@field public character              integer

---@type table<string, table<vim.lsp.Client, table<number, boolean>>>
local supports_method = {}

---! Check if cursor is within range
---@param cursor                      eve.lib.lsp.ISymbolPos
---@param range                       { start: eve.lib.lsp.ISymbolPos, end: eve.lib.lsp.ISymbolPos }
---@return boolean
local function is_within_range(cursor, range)
  local start = range.start ---@type eve.lib.lsp.ISymbolPos
  local finish = range["end"] ---@type eve.lib.lsp.ISymbolPos
  return (cursor.line > start.line or (cursor.line == start.line and cursor.character >= start.character))
    and (cursor.line < finish.line or (cursor.line == finish.line and cursor.character <= finish.character))
end

---@param client                        vim.lsp.Client
---@return nil
local function check_methods(client, bufnr)
  -- don't trigger on invalid buffers
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- don't trigger on non-listed buffers
  if not vim.bo[bufnr].buflisted then
    return
  end

  -- don't trigger on nofile buffers
  if vim.bo[bufnr].buftype == "nofile" then
    return
  end

  for method, clients in pairs(supports_method) do
    clients[client] = clients[client] or {}
    if not clients[client][bufnr] then
      if client.supports_method and client.supports_method(method, { bufnr = bufnr }) then
        clients[client][bufnr] = true
        vim.api.nvim_exec_autocmds("User", {
          pattern = "LspSupportsMethod",
          data = { client_id = client.id, buffer = bufnr, method = method },
        })
      end
    end
  end
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = augroup("check_methods_on_lsp_attach"),
  callback = function(args)
    local bufnr = args.buf ---@type integer
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      check_methods(client, bufnr)
    end
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = augroup("check_methods_on_lsp_dynamic_capability"),
  pattern = "LspDynamicCapability",
  callback = function(args)
    local bufnr = args.data.buffer ---@type number
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      check_methods(client, bufnr)
    end
  end,
})

---@class eve.lib.lsp
local M = {}

---@param method                        string
---@param fn                            fun(client: vim.lsp.Client, bufnr: integer): nil
function M.on_supports_method(method, fn)
  supports_method[method] = supports_method[method] or setmetatable({}, { __mode = "k" })

  return vim.api.nvim_create_autocmd("User", {
    group = augroup("trigger_lsp_supports_method"),
    pattern = "LspSupportsMethod",
    callback = function(args)
      local bufnr = args.data.buffer ---@type number
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and method == args.data.method then
        return fn(client, bufnr)
      end
    end,
  })
end

---@param bufnr                         integer
---@param method                        string
---@return boolean
function M.has_support_method(bufnr, method)
  method = method:find("/") and method or "textDocument/" .. method
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client.supports_method(method) then
      return true
    end
  end
  return false
end

---! Find the symbol path recursively
---@param cursor                      eve.lib.lsp.ISymbolPos
---@param symbols                     any[]
function M.find_symbol_path(cursor, symbols)
  for _, symbol in ipairs(symbols) do
    if symbol.location then
      local range = symbol.location.range
      if is_within_range(cursor, range) then
        return { symbol }
      end
    elseif symbol.range then
      local range = symbol.range
      if is_within_range(cursor, range) then
        local path = { symbol }
        if symbol.children then
          local child_path = M.find_symbol_path(cursor, symbol.children)
          if child_path then
            for _, child_symbol in ipairs(child_path) do
              path[#path + 1] = child_symbol
            end
          end
        end
        return path
      end
    end
  end
  return nil
end

return M
