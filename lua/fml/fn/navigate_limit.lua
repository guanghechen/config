---@param current                       number  current index
---@param step                          number  moving step
---@param total                         number  total index.
---@return number
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
