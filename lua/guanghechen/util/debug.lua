---@class guanghechen.util.debug

local M = {}

---@param value any
---@return string
function M.inspect(value)
  return vim.fn.inspect(value)
end

return M
