local M = {}

---@param ...                           any[]
---@return boolean
---@diagnostic disable-next-line: unused-vararg
function M.falsy(...)
  return false
end

---@param value                         any
---@return any
function M.identity(value)
  return value
end

---@param ...                           any[]
---@return any
function M.noop(...) end

---@param ...                           any[]
---@return boolean
---@diagnostic disable-next-line: unused-vararg
function M.truthy(...)
  return true
end

---@param min                           number
---@param max                           number
---@param value                         number
function M.minmax(min, max, value)
  return math.min(max, math.max(min, value))
end

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
