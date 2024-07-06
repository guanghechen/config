local std_string = require("fml.std.string")

---@class fml.std.array
local M = {}

---@generic T
---@param arr                           T[]
---@param element                       T
---@return boolean
function M.contains(arr, element)
  for i = 1, #arr, 1 do
    if arr[i] == element then
      return true
    end
  end
  return false
end

---@generic T
---@param arr1                          T[]
---@param arr2                          T[]
---@return boolean
function M.equals(arr1, arr2)
  if arr1 == arr2 then
    return true
  end
  if #arr1 ~= #arr2 then
    return false
  end
  for i = 1, #arr1, 1 do
    if arr1[i] ~= arr2[i] then
      return false
    end
  end
  return true
end

---@generic T
---@param arr                           T[]
---@param filter                        fun(v: T, i: integer, arr: T[]): boolean
---@return T[]
function M.filter(arr, filter)
  local N = #arr ---@type integer
  local result = {}
  for i = 1, N, 1 do
    local value = arr[i]
    if filter(value, i, arr) then
      table.insert(result, value)
    end
  end
  return result
end

---@generic T
---@param arr                           T[]
---@param filter                        fun(v: T, i: integer, arr: T[]): boolean
---@return T[]
function M.filter_inline(arr, filter)
  local N = #arr ---@type integer
  local k = 1 ---@type integer

  for i = 2, N, 1 do
    local value = arr[i]
    if filter(value, i, arr) then
      k = k + 1
      arr[k] = value
    end
  end
  for _ = k + 1, N, 1 do
    table.remove(arr)
  end
  return arr
end

---@param arr                           string[]
---@return string[]
function M.filter_non_blank_string(arr)
  return M.filter(arr, std_string.is_non_blank_string)
end

---@generic T
---@param arr                           T[]
---@param check                         fun(ele: T, index: integer, arr: T[]): boolean
---@return T|nil
function M.find(arr, check)
  for i = 1, #arr, 1 do
    local v = arr[i]
    if check(v, i, arr) then
      return v
    end
  end
  return nil
end

---@generic T
---@param arr                           T[]
---@param element                       T|fun(ele: T, index: integer, arr: T[]): boolean
---@return integer|nil
function M.first(arr, element)
  if type(element) == "function" then
    for i = 1, #arr, 1 do
      local v = arr[i]
      if element(v, i, arr) then
        return i
      end
    end
  else
    for i = 1, #arr, 1 do
      if arr[i] == element then
        return i
      end
    end
  end
  return nil
end

---@generic T
---@param arr                           T[]
---@param element                       T|fun(ele: T, index: integer, arr: T[]): boolean
---@return integer|nil
function M.last(arr, element)
  if type(element) == "function" then
    for i = #arr, 1, -1 do
      local v = arr[i]
      if element(v, i, arr) then
        return i
      end
    end
  else
    for i = #arr, 1, -1 do
      if arr[i] == element then
        return i
      end
    end
  end
  return nil
end

---@generic T1
---@generic T2
---@param arr                           T1[]
---@param map                           fun(v: T1, i: integer, arr: T1[]): T2
---@param filter                        ?fun(v: T2): boolean
---@return T2[]
function M.map(arr, map, filter)
  local result = {}
  for i = 1, #arr do
    local value = arr[i]
    local next_value = map(value, i, arr)
    if filter == nil or filter(next_value) then
      table.insert(result, next_value)
    end
  end
  return result
end

---@param ...                           any[][]
---@return any[]
function M.merge_multiple_array(...)
  local result = {}
  for _, tbl in ipairs({ ... }) do
    for _, v in ipairs(tbl) do
      table.insert(result, v)
    end
  end
  return result
end

---@param str                           string
---@param separator_pattern             ?string
---@return string[]
function M.parse_comma_list(str, separator_pattern)
  separator_pattern = separator_pattern or ","
  local result = {}
  local items = std_string.split(str, separator_pattern)
  for _, item in ipairs(items) do
    local v = item:match("^%s*(.-)%s*$")
    if #v > 0 then
      table.insert(result, v)
    end
  end
  return result
end

---@generic T
---@param arr                           T[]
---@param start                         ?integer
---@param stop                          ?integer
---@return T[]
function M.slice(arr, start, stop)
  start = math.max(1, start or 1)
  stop = math.min(#arr, stop or #arr)
  if start > stop then
    return {}
  end

  local result = {}
  for i = start, stop, 1 do
    table.insert(result, arr[i])
  end
  return result
end

---@param items                         string[]
---@param sep                           string
---@return string
function M.to_comma_list(items, sep)
  return table.concat(items, sep or ",")
end

---@param strs                                         string[]
---@return string[]
function M.trim_and_filter(strs)
  return M.map(strs, function(v)
    return v:match("^%s*(.-)%s*$")
  end, function(v)
    return #v > 0
  end)
end

return M
