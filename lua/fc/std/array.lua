local std_string = require("fc.std.string")

---@class fc.std.array
local M = {}

---@generic T
---@param arr                           T[]
---@param element                       T|fun(v: T, i: integer, arr: T[]): boolean
---@return boolean
function M.contains(arr, element)
  if type(element) == "function" then
    for i = 1, #arr, 1 do
      if element(arr[i], i, arr) then
        return true
      end
    end
    return false
  end

  for i = 1, #arr, 1 do
    if arr[i] == element then
      return true
    end
  end
  return false
end

---@generic T
---@param arr                           T[]
---@param filter                        fun(v: T, i: integer, arr: T[]): boolean
---@return integer
function M.count(arr, filter)
  local N = #arr ---@type integer
  local count = 0
  for i = 1, N, 1 do
    local value = arr[i]
    if filter(value, i, arr) then
      count = count + 1
    end
  end
  return count
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
---@return boolean
function M.every(arr, filter)
  local N = #arr ---@type integer
  for i = 1, N, 1 do
    local value = arr[i]
    if not filter(value, i, arr) then
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
---@param filter                        T|fun(ele: T, index: integer, arr: T[]): boolean
---@return integer|nil
---@return T|nil
function M.first(arr, filter)
  if type(filter) == "function" then
    for i = 1, #arr, 1 do
      local v = arr[i]
      if filter(v, i, arr) then
        return i, v
      end
    end
  else
    for i = 1, #arr, 1 do
      local v = arr[i]
      if v == filter then
        return i, v
      end
    end
  end
  return nil, nil
end

---@generic T
---@param arr                           T[]
---@param element                       T|fun(ele: T, index: integer, arr: T[]): boolean
---@return integer|nil
---@return T|nil
function M.last(arr, element)
  if type(element) == "function" then
    for i = #arr, 1, -1 do
      local v = arr[i]
      if element(v, i, arr) then
        return i, v
      end
    end
  else
    for i = #arr, 1, -1 do
      local v = arr[i]
      if v == element then
        return i, v
      end
    end
  end
  return nil, nil
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
function M.concat(...)
  local result = {}
  for _, tbl in ipairs({ ... }) do
    for _, v in ipairs(tbl) do
      table.insert(result, v)
    end
  end
  return result
end

---@param base                          any[]
---@param ...                           any[][]
---@return nil
function M.extend(base, ...)
  local result = base
  for _, tbl in ipairs({ ... }) do
    for _, v in ipairs(tbl) do
      table.insert(result, v)
    end
  end
end

---@param str                           string
---@param separator_pattern             ?string
---@return string[]
function M.parse_comma_list(str, separator_pattern)
  separator_pattern = separator_pattern or ","
  local result = {} ---@type string[]
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

  local result = {}
  for i = start, stop, 1 do
    table.insert(result, arr[i])
  end
  return result
end

---@generic T
---@param arr                           T[]
---@param filter                        fun(v: T, i: integer, arr: T[]): boolean
---@return boolean
function M.some(arr, filter)
  local N = #arr ---@type integer
  for i = 1, N, 1 do
    local value = arr[i]
    if filter(value, i, arr) then
      return true
    end
  end
  return false
end

---@param items                         string[]
---@param sep                           ?string
---@return string
function M.to_comma_list(items, sep)
  return table.concat(items, sep or ",")
end

---@generic T
---@param elements                      T[]
---@return table<T, boolean>
function M.to_set(elements)
  local set = {}
  for i = 1, #elements, 1 do
    set[elements[i]] = true
  end
  return set
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
