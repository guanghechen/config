---@class std.table
local M = {}

---@generic T
---@param elements                      T[]
---@param filter                        fun(element: T, index: integer, elements: T[]): boolean
---@return integer
function M.count(elements, filter)
  local count = 0 ---@type integer
  for index = 1, #elements, 1 do
    if filter(elements[index], index, elements) then
      count = count + 1 ---@type integer
    end
  end
  return count
end

---@generic T
---@param elements                      T[]
---@param filter                        fun(element: T, index: integer, elements: T[]): boolean
---@return T[]
function M.filter(elements, filter)
  local result = {}
  for index = 1, #elements, 1 do
    if filter(elements[index], index, elements) then
      result[#result + 1] = elements[index]
    end
  end
  return result
end

---@generic T
---@param elements                      T[]
---@param filter                        fun(element: T, index: integer): boolean
---@return nil
function M.filter_inline(elements, filter)
  local N = #elements ---@type integer
  if N > 0 then
    local k = 1 ---@type integer
    for index = 1, N, 1 do
      if filter(elements[index], index) then
        elements[k] = elements[index]
        k = k + 1
      end
    end

    for index = N, k, -1 do
      elements[index] = nil
    end
  end
end

---@generic T
---@param elements                      T[]
---@param element                       T|fun(element: T, index: integer): boolean
---@return integer|nil
function M.find_index(elements, element)
  if type(element) == "function" then
    for i = 1, #elements, 1 do
      if element(elements[i], i) then
        return i
      end
    end
  else
    for i = 1, #elements, 1 do
      if elements[i] == element then
        return i
      end
    end
  end
end

--- Merges the values similar to vim.tbl_deep_extend with the **force** behavior,
--- but the values can be any type
---@generic T
---@param ... T
---@return T
function M.merge_config(...)
  local ret = select(1, ...)
  for i = 2, select("#", ...) do
    local value = select(i, ...)
    if std.is.dict_like(ret) and std.is.dict(value) then
      for k, v in pairs(value) do
        ret[k] = M.merge_config(ret[k], v)
      end
    elseif value ~= nil then
      ret = value
    end
  end
  return ret
end

---@param elements                      string[]
---@return table<string, true>
function M.to_string_set(elements)
  local set = {} ---@type table<string, true>
  for _, element in ipairs(elements) do
    set[element] = true
  end
  return set
end

---@generic T
---@param elements                      T[]
---@param max_length                   integer
---@return nil
function M.truncate_inline(elements, max_length)
  local N = #elements ---@type integer
  if N > max_length then
    local L = max_length + 1 ---@type integer
    for index = N, L, -1 do
      elements[index] = nil
    end
  end
end

--- Stable sort implementation using merge sort algorithm
--- Sorts the table in-place while maintaining stability (equal elements keep their relative order)
--- Memory-optimized version that reuses a single auxiliary array
---@generic T
---@param list                          T[]
---@param cmp                           fun(a: T, b: T): integer
---@return nil
do
  local aux_pool = {} ---@type any[]
  local pool_size = 0 ---@type integer
  
  function M.stable_sort(list, cmp)
    local n = #list
    if n <= 1 then
      return
    end

    -- Reuse or expand auxiliary array
    local aux = aux_pool
    if pool_size < n then
      for i = pool_size + 1, n do
        aux[i] = nil
      end
      pool_size = n
    end
    
    local function merge(left, mid, right)
      for i = left, mid do
        aux[i] = list[i]
      end

      local i, j, k = left, mid + 1, left

      while i <= mid and j <= right do
        if cmp(list[j], aux[i]) >= 0 then
          list[k] = aux[i]
          i = i + 1
        else
          list[k] = list[j]
          j = j + 1
        end
        k = k + 1
      end

      while i <= mid do
        list[k] = aux[i]
        i = i + 1
        k = k + 1
      end
    end

    local function merge_sort_recursive(left, right)
      if left < right then
        local mid = math.floor((left + right) / 2)
        merge_sort_recursive(left, mid)
        merge_sort_recursive(mid + 1, right)
        merge(left, mid, right)
      end
    end

    merge_sort_recursive(1, n)
  end
end

return M
