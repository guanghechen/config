---@class eve.std.fn
local M = {}

---@param ...                           any[]
---@return boolean
---@diagnostic disable-next-line: unused-vararg
function M.falsy(...)
  return false
end

---@param ...                           any[]
---@return boolean
---@diagnostic disable-next-line: unused-vararg
function M.truthy(...)
  return true
end

---@param value                         any
---@return any
function M.identity(value)
  return value
end

---@param ...                           any[]
---@return any
function M.noop(...) end

----------------------------------------------------------------------------------------------------

---@param left                          any
---@param right                         any
---@return boolean
function M.equals_deep(left, right)
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
    if not M.equals_deep(left[i], right[i]) then
      return false
    end
  end

  for key, val in pairs(left) do
    if not M.equals_deep(val, right[key]) then
      return false
    end
  end

  for key, val in pairs(right) do
    if not M.equals_deep(val, left[key]) then
      return false
    end
  end

  return true
end

---@param left                          any
---@param right                         any
---@return boolean
function M.equals_shallow(left, right)
  return left == right
end

---@param left                          any[]
---@param right                         any[]
---@param deep                          ?boolean
---@return boolean
function M.equals_list(left, right, deep)
  if left == right then
    return true
  end

  if #left ~= #right then
    return false
  end

  local N = #left ---@type integer
  if not deep then
    for i = 1, N, 1 do
      if left[i] ~= right[i] then
        return false
      end
    end
    return true
  end

  local equals = M.equals_deep
  for i = 1, N, 1 do
    if not equals(left[i], right[i]) then
      return false
    end
  end
  return true
end

return M
