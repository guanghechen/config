---@class guanghechen.util.table
local M = {}

---@generic T
---@param arr T[]
---@param filter? fun(i, v):boolean
---@return T[]
function M.filter_array(arr, filter)
  local i = 1
  local size = #arr
  local result = {}

  if filter then
    while i <= size do
      local value = arr[i]
      if filter(i, value) then
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
    return type(x) == "string" and #x < 1
  end)
end

return M
