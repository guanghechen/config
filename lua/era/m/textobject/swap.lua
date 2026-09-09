---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.textobject.swap" ---@type string

local Source = require("era.m.textobject.source")

local M = {}

---@class era.m.textobject.ISwapEdit
---@field public range                  era.m.textobject.Range
---@field public lines                  string[]
---@field public cursor                 integer[] One-based row, zero-based byte column

---Plan a rotation inside one parameter container before performing a single buffer edit.
---@param lines                         string[]
---@param ranges                        era.m.textobject.Range[]
---@param position                      integer[] Zero-based row and byte column
---@param direction                     integer -1 or 1
---@param count                         integer
---@return era.m.textobject.ISwapEdit|nil
function M.plan(lines, ranges, position, direction, count)
  if count < 1 then
    return nil
  end
  local source = Source.new(lines)
  local offset = Source.offset(source, position[1], position[2]) ---@type integer
  local current = nil ---@type era.m.textobject.Range|nil
  local width = math.huge ---@type number
  for _, range in ipairs(ranges) do
    local span = Source.span(source, range)
    if span.from <= offset and offset < span.to and span.to - span.from < width then
      current, width = range, span.to - span.from
    end
  end
  if current == nil or current.container == nil then
    return nil
  end

  local siblings = {} ---@type era.m.textobject.Range[]
  for _, range in ipairs(ranges) do
    if range.container == current.container then
      siblings[#siblings + 1] = range
    end
  end
  table.sort(siblings, function(left, right)
    return left[1] < right[1] or (left[1] == right[1] and left[2] < right[2])
  end)
  local current_index = 0 ---@type integer
  for index, range in ipairs(siblings) do
    if range == current then
      current_index = index
      break
    end
  end
  local target = current_index + direction * count ---@type integer
  if target < 1 or target > #siblings then
    return nil
  end

  local first, last = math.min(current_index, target), math.max(current_index, target)
  local texts, spans = {}, {} ---@type string[], era.m.textobject.ISpan[]
  for index = first, last do
    local span = Source.span(source, siblings[index])
    if span.from == span.to or (#spans > 0 and span.from < spans[#spans].to) then
      return nil
    end
    spans[#spans + 1] = span
    texts[#texts + 1] = source.text:sub(span.from, span.to - 1)
  end

  local chunks = {} ---@type string[]
  local size, cursor_offset = 0, 0
  for index, span in ipairs(spans) do
    local text_index = direction > 0 and (index % #texts + 1) or ((index - 2) % #texts + 1) ---@type integer
    if text_index == current_index - first + 1 then
      cursor_offset = size
    end
    chunks[#chunks + 1] = texts[text_index]
    size = size + #texts[text_index]
    if index < #spans then
      local between = source.text:sub(span.to, spans[index + 1].from - 1) ---@type string
      chunks[#chunks + 1] = between
      size = size + #between
    end
  end

  local replacement = table.concat(chunks) ---@type string
  local prefix = replacement:sub(1, cursor_offset) ---@type string
  local _, newlines = prefix:gsub("\n", "")
  local column = #assert(prefix:match("[^\n]*$")) ---@type integer
  local start_range, end_range = siblings[first], siblings[last]
  if newlines == 0 then
    column = column + start_range[2]
  end
  return {
    range = { start_range[1], start_range[2], end_range[3], end_range[4] },
    lines = vim.split(replacement, "\n", { plain = true }),
    cursor = { start_range[1] + newlines + 1, column },
  }
end

return M
