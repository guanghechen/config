---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject.source" ---@type string

local M = {}

---@param lines                         string[]
---@param first_row                     ?integer
---@return era.m.textobject.ISource
function M.new(lines, first_row)
  local starts = {} ---@type integer[]
  local offset = 1 ---@type integer
  for index, line in ipairs(lines) do
    starts[index] = offset
    offset = offset + #line + 1
  end
  return { lines = lines, text = table.concat(lines, "\n") .. "\n", starts = starts, first_row = first_row or 0 }
end

---@param source                        era.m.textobject.ISource
---@param row                           integer
---@param col                           integer
---@return integer
function M.offset(source, row, col)
  local index = row - source.first_row + 1 ---@type integer
  if index > #source.lines then
    return #source.text + 1
  end
  return source.starts[index] + col
end

---@param source                        era.m.textobject.ISource
---@param offset                        integer
---@return integer
---@return integer
function M.position(source, offset)
  if offset == #source.text + 1 then
    return source.first_row + #source.lines, 0
  end
  local left, right = 1, #source.starts
  while left < right do
    local middle = math.ceil((left + right) / 2) ---@type integer
    if source.starts[middle] <= offset then
      left = middle
    else
      right = middle - 1
    end
  end
  return source.first_row + left - 1, offset - source.starts[left]
end

---@param source                        era.m.textobject.ISource
---@param range                         era.m.textobject.Range
---@return era.m.textobject.ISpan
function M.span(source, range)
  return { from = M.offset(source, range[1], range[2]), to = M.offset(source, range[3], range[4]) }
end

---@param source                        era.m.textobject.ISource
---@param span                          era.m.textobject.ISpan
---@param vis_mode                      ?string
---@return era.m.textobject.Range
function M.range(source, span, vis_mode)
  local start_row, start_col = M.position(source, span.from)
  local end_row, end_col = M.position(source, span.to)
  return { start_row, start_col, end_row, end_col, vis_mode = vis_mode }
end

return M
