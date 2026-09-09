---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.list" ---@type string

local M = {}

---@param selected                      integer 0-indexed, -1 means original input
---@param count                         integer
---@param direction                     -1|1
---@return integer
function M.move(selected, count, direction)
  if count <= 0 then
    return -1
  end
  if direction > 0 then
    return selected < count - 1 and selected + 1 or -1
  end
  return selected > 0 and selected - 1 or selected < 0 and count - 1 or -1
end

---@param index                         integer 1-indexed
---@param count                         integer
---@return integer|nil 0-indexed
function M.resolve(index, count)
  if index < 1 or index > count then
    return nil
  end
  return index - 1
end

return M
