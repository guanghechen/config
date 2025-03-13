---@class eve.std.array
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
