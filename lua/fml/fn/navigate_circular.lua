---@param current                       integer  current index
---@param step                          integer  moving step
---@param total                         integer  total index.
---@return integer
local function navigate_circular(current, step, total)
  local candidate = (current + step - 1) % total

  while candidate < 0 do
    candidate = candidate + total
  end

  while candidate >= total do
    candidate = candidate - total
  end

  return candidate + 1
end

return navigate_circular
