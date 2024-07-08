---@class fml.std.set
local M = {}

---@param integers                      integer[]
---@return table<integer, boolean>
function M.from_integer_array(integers)
  local set = {} ---@type table<integer, boolean>
  for i = 1, #integers, 1 do
    set[integers[i]] = true
  end
  return set
end

return M
