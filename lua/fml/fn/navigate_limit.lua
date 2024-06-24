---@param current                       integer  current index
---@param step                          integer  moving step
---@param total                         integer  total index.
---@return integer
local function navigate_limit(current, step, total)
  local candidate = current + step

  if candidate < 1 then
    return 1
  end

  if candidate > total then
    return total
  end

  return candidate
end

return navigate_limit
