---@class guanghechen.util.debug
local M = {}

---@param value any
---@return string|nil
function M.inspect(value)
  return (value == nil or type(value) == "string") and value or vim.inspect(value)
end

return M
