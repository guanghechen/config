---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.dirty" ---@type string

---@class era.dressing.hipattern.dirty.IRange
---@field public from                   integer
---@field public to                     integer

---@class era.dressing.hipattern.dirty
local M = {}

---@param ranges                        era.dressing.hipattern.dirty.IRange[]
---@param from                          integer
---@param to                            integer
---@return era.dressing.hipattern.dirty.IRange[]
function M.add(ranges, from, to)
  if from >= to then
    return ranges
  end

  local result = {} ---@type era.dressing.hipattern.dirty.IRange[]
  local pending = { from = from, to = to } ---@type era.dressing.hipattern.dirty.IRange
  local inserted = false ---@type boolean

  for _, range in ipairs(ranges) do
    if range.to < pending.from then
      result[#result + 1] = range
    elseif pending.to < range.from then
      if not inserted then
        result[#result + 1] = pending
        inserted = true
      end
      result[#result + 1] = range
    else
      pending.from = math.min(pending.from, range.from)
      pending.to = math.max(pending.to, range.to)
    end
  end

  if not inserted then
    result[#result + 1] = pending
  end
  return result
end

---@param ranges                        era.dressing.hipattern.dirty.IRange[]
---@param first                         integer
---@param last_orig                     integer
---@param last_new                      integer
---@return era.dressing.hipattern.dirty.IRange[]
function M.transform(ranges, first, last_orig, last_new)
  if #ranges == 0 or last_orig == last_new then
    return ranges
  end

  local delta = last_new - last_orig ---@type integer
  ---@param row                         integer
  ---@return integer
  local function transform_row(row)
    if row <= first then
      return row
    end
    if row >= last_orig then
      return row + delta
    end
    return first
  end

  local result = {} ---@type era.dressing.hipattern.dirty.IRange[]
  for _, range in ipairs(ranges) do
    local range_from = math.max(0, transform_row(range.from)) ---@type integer
    local range_to = math.max(range_from, transform_row(range.to)) ---@type integer
    result = M.add(result, range_from, range_to)
  end
  return result
end

return M
