---@class eve.builtin.lsp.ISymbolPos
---@field public line                   integer
---@field public character              integer

---! Check if cursor is within range
---@param cursor                      eve.builtin.lsp.ISymbolPos
---@param range                       { start: eve.builtin.lsp.ISymbolPos, end: eve.builtin.lsp.ISymbolPos }
---@return boolean
local function is_within_range(cursor, range)
  local start = range.start ---@type eve.builtin.lsp.ISymbolPos
  local finish = range["end"] ---@type eve.builtin.lsp.ISymbolPos
  return (cursor.line > start.line or (cursor.line == start.line and cursor.character >= start.character))
    and (cursor.line < finish.line or (cursor.line == finish.line and cursor.character <= finish.character))
end

---@class eve.builtin.lsp
local M = {}

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
---@param cursor                      eve.builtin.lsp.ISymbolPos
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
