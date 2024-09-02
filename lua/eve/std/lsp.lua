---@class eve.std.lsp
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

return M
