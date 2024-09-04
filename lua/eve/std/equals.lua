---@class eve.std.equals
local M = {}

---@param left                          any
---@param right                         any
---@return boolean
function M.deep_equals(left, right)
  if left == right then
    return true
  end

  if type(left) ~= "table" or type(right) ~= "table" then
    return false
  end

  if #left ~= #right then
    return false
  end

  for i = 0, #left, 1 do
    if not M.deep_equals(left[i], right[i]) then
      return false
    end
  end

  for key, val in pairs(left) do
    if not M.deep_equals(val, right[key]) then
      return false
    end
  end

  for key, val in pairs(right) do
    if not M.deep_equals(val, left[key]) then
      return false
    end
  end

  return true
end

---@param left                          any
---@param right                         any
---@return boolean
function M.shallow_equals(left, right)
  return left == right
end

return M
