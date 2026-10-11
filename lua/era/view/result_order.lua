---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.view.result_order" ---@type string

local M = {}

---Stable result ordering with cooperative checkpoints; the returned array may replace the input.
---@generic T
---@param values                        T[]
---@param less                          fun(left: T, right: T): boolean
---@param checkpoint                    fun(): nil
---@return T[]
function M.sort(values, less, checkpoint)
  local count, width = #values, 1
  local scratch = {}
  local remaining = 256
  while width < count do
    for first = 1, count, width * 2 do
      local middle, last = math.min(first + width, count + 1), math.min(first + width * 2, count + 1)
      local left, right = first, middle
      for at = first, last - 1 do
        if right == last or left < middle and not less(values[right], values[left]) then
          scratch[at], left = values[left], left + 1
        else
          scratch[at], right = values[right], right + 1
        end
        remaining = remaining - 1
        if remaining == 0 then
          remaining = 256
          checkpoint()
        end
      end
    end
    values, scratch = scratch, values
    width = width * 2
  end
  checkpoint()
  return values
end

return M
