---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.stats" ---@type string

-- Statistics shared by the Lua benchmarks; they match script/benchmark/stats.mjs and leave their input unchanged.
-- Plain LuaJIT runs some benchmarks, so this module does not use `vim`.
local M = {}

---@param values                        number[]
---@return number[]
local function sorted(values)
  local copy = {}
  for index, value in ipairs(values) do
    copy[index] = value
  end
  table.sort(copy)
  return copy
end

---Median of `values`; nil when empty.
---@param values                        number[]
---@return number|nil
function M.median(values)
  if #values == 0 then
    return nil
  end
  local ordered = sorted(values)
  local middle = math.floor(#ordered / 2)
  return #ordered % 2 == 1 and ordered[middle + 1] or (ordered[middle] + ordered[middle + 1]) / 2
end

---Nearest-rank percentile: the smallest value with at least `fraction` of the values at or below it; nil when empty.
---@param values                        number[]
---@param fraction                      number
---@return number|nil
function M.percentile(values, fraction)
  if #values == 0 then
    return nil
  end
  local ordered = sorted(values)
  return ordered[math.min(#ordered, math.max(1, math.ceil(#ordered * fraction)))]
end

return M
