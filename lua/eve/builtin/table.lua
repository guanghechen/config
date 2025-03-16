---@class eve.builtin.table
local M = {}

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
    if eve.std.is.dict_like(ret) and eve.std.is.dict(value) then
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

return M
