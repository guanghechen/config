---@class guanghechen.util.math
local M = {}

---@param current number  current index
---@param step    number  moving step
---@param total   number  total index.
function M.move_index_circular(current, step, total)
  local candiate = (current + step - 1) % total

  while candiate < 0 do
    candiate = candiate + total
  end

  while candiate >= total do
    candiate = candiate - total
  end

  return candiate + 1
end

---@param current number  current index
---@param step    number  moving step
---@param total   number  total index.
function M.move_index_limit(current, step, total)
  local candiate = current + step

  if candiate < 1 then
    return 1
  end

  if candiate > total then
    return total
  end

  return candiate
end

return M
