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

    for index = N, k, 1 do
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

return M
