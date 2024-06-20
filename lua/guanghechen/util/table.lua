local util_string = require("guanghechen.util.string")

---@class guanghechen.util.table
local M = {}

---@generic T
---@param arr T[]
---@param start? integer
---@param stop? integer
---@return T[]
function M.slice(arr, start, stop)
  local result = {}
  start = start or 1
  stop = stop or #arr

  if start < 1 then
    start = 1
  end

  if stop > #arr then
    stop = #arr
  end

  for i = start, stop do
    result[i] = arr[i]
  end
  return result
end

function M.equals_array(arr1, arr2)
  if arr1 == arr2 then
    return true
  end

  if #arr1 ~= #arr2 then
    return false
  end

  for i = 1, #arr1 do
    if arr1[i] ~= arr2[i] then
      return false
    end
  end

  return true
end

---@generic T
---@param arr T[]
---@param filter? fun(v, i):boolean
---@return T[]
function M.filter(arr, filter)
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

---@generic T1
---@generic T2
---@param arr T1[]
---@param map fun(v: T1, i: integer): T2
---@param filter? fun(v: T2): boolean
---@return T2[]
function M.map(arr, map, filter)
  local result = {}
  for i = 1, #arr do
    local value = arr[i]
    local next_value = map(value, i)
    if filter == nil or filter(next_value) then
      table.insert(result, next_value)
    end
  end
  return result
end

---@param arr string[]
---@return string[]
function M.filter_non_blank_string(arr)
  return M.filter(arr, function(x)
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

---@param strs string[]
---@return string[]
function M.trim_and_filter(strs)
  return M.map(strs, function(v)
    return v:match("^%s*(.-)%s*$")
  end, function(v)
    return #v > 0
  end)
end

---@param str string
---@param separator_pattern? string
---@return string[]
function M.parse_comma_list(str, separator_pattern)
  separator_pattern = separator_pattern or ","
  local result = {}
  local items = util_string.split(str, separator_pattern)
  for _, item in ipairs(items) do
    local v = item:match("^%s*(.-)%s*$")
    if #v > 0 then
      table.insert(result, v)
    end
  end
  return result
end

return M
