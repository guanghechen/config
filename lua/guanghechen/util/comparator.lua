---@class guanghechen.util.comparator
local M = {}

---@generic T
---@param x T
---@param y T
---@return boolean
function M.shallow_equals(x, y)
  return x == y
end

return M
