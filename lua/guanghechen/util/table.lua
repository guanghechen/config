---@class guanghechen.util.table
local M = {}

---@generic T
---@param arr T[]
---@param filter? fun(v, i):boolean
---@return T[]
function M.filter_array(arr, filter)
  local i = 1
  local size = #arr
  local result = {}

  if filter then
    while i <= size do
      local value = arr[i]
      if filter(value, i) then
        table.insert(result, value)
      end
      i = i + 1
    end
  else
    while i <= size do
      table.insert(result, arr[i])
      i = i + 1
    end
  end
  return result
end

---@param arr string[]
---@return string[]
function M.filter_non_blank_string(arr)
  return M.filter_array(arr, function(x)
    return type(x) == "string" and #x > 0
  end)
end

return M
