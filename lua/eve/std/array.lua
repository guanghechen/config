---@class eve.std.array
local M = {}

---@generic T
---@param arr                           T[]
---@param element                       T
function M.toggle_inline(arr, element)
  local N = #arr ---@type integer
  local k = 0 ---@type integer
  for i = 1, N, 1 do
    local val = arr[i]
    if val ~= element then
      k = k + 1
      arr[k] = val
    end
  end

  if k == N then
    arr[N + 1] = element
  else
    arr[N] = nil
  end
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

---@param str                           string
---@return string[]
function M.parse_comma_list(str)
  local result = {} ---@type string[]
  local items = vim.split(str, ",")
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

return M
