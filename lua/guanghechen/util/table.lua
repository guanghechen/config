---@class guanghechen.util.table
local M = {}

---@generic T
---@param arr T[]
---@return T[]
function M.clone_array(arr)
  local result = {}
  for i = 1, #arr do
    result[i] = arr[i]
  end
  return result
end

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

function M.merge_multiple_array(...)
  local result = {}
  for _, tbl in ipairs({ ... }) do
    for _, v in ipairs(tbl) do
      table.insert(result, v)
    end
  end
  return result
end

return M
