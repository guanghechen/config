---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.surrounds.buffer" ---@type string

local NSNR_HIGHLIGHT = vim.api.nvim_create_namespace(__module_name__ .. ":highlight") ---@type integer

---@class era.m.surrounds.buffer
local M = {}

---@param bufnr                         integer
---@return boolean
function M.is_available(bufnr)
  if bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  if vim.api.nvim_get_option_value("readonly", { buf = bufnr }) then
    return false
  end
  if not vim.api.nvim_get_option_value("modifiable", { buf = bufnr }) then
    return false
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  return stl.filetype.is_surround_enabled(filetype)
end

---@param mode                          string
---@return "charwise"|"linewise"|"blockwise"
local function get_selection_type(mode)
  if mode == "char" or (mode == "visual" and vim.fn.visualmode() == "v") then
    return "charwise"
  end
  if mode == "line" or (mode == "visual" and vim.fn.visualmode() == "V") then
    return "linewise"
  end
  return "blockwise"
end

---@param mode                          string
---@return era.m.surrounds.IMarks
function M.get_marks(mode)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local mark_first = mode == "visual" and "<" or "[" ---@type string
  local mark_second = mode == "visual" and ">" or "]" ---@type string
  local pos_first = vim.api.nvim_buf_get_mark(bufnr, mark_first) ---@type integer[]
  local pos_second = vim.api.nvim_buf_get_mark(bufnr, mark_second) ---@type integer[]
  local selection_type = get_selection_type(mode) ---@type "charwise"|"linewise"|"blockwise"

  if selection_type == "linewise" then
    local first_line = vim.api.nvim_buf_get_lines(bufnr, pos_first[1] - 1, pos_first[1], true)[1] or "" ---@type string
    local second_line = vim.api.nvim_buf_get_lines(bufnr, pos_second[1] - 1, pos_second[1], true)[1] or "" ---@type string
    local _, first_indent = first_line:find("^%s*")
    local second_trailing = second_line:find("%s*$") or (#second_line + 1) ---@type integer
    pos_first[2] = first_indent or 0
    pos_second[2] = math.max(0, second_trailing - 2)
  end

  pos_first[2] = pos_first[2] + 1
  pos_second[2] = pos_second[2] + 1

  if mode == "visual" and vim.o.selection == "exclusive" then
    pos_second[2] = pos_second[2] - 1
  else
    local line = vim.api.nvim_buf_get_lines(bufnr, pos_second[1] - 1, pos_second[1], true)[1] or "" ---@type string
    local utf_index = vim.str_utfindex(line, "utf-32", math.min(#line, pos_second[2])) ---@type integer
    pos_second[2] = vim.str_byteindex(line, "utf-32", utf_index) ---@type integer
  end

  return {
    first = { line = pos_first[1], col = pos_first[2] },
    second = { line = pos_second[1], col = pos_second[2] },
    selection_type = selection_type,
  }
end

---@param line                          integer
---@param col                           integer
---@return nil
function M.set_cursor(line, col)
  vim.api.nvim_win_set_cursor(0, { line, col - 1 })
end

---@param line                          integer
---@return nil
function M.set_cursor_nonblank(line)
  M.set_cursor(line, 1)
  vim.cmd("normal! ^")
end

---@param pos1                          era.m.surrounds.IPosition
---@param pos2                          era.m.surrounds.IPosition
---@return "<"|">"|"="
function M.compare_positions(pos1, pos2)
  if pos1.line < pos2.line then
    return "<"
  end
  if pos1.line > pos2.line then
    return ">"
  end
  if pos1.col < pos2.col then
    return "<"
  end
  if pos1.col > pos2.col then
    return ">"
  end
  return "="
end

---@param positions                    era.m.surrounds.IPosition[]
---@param direction                    "left"|"right"
---@return nil
function M.cycle_cursor(positions, direction)
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  local current = { line = cursor[1], col = cursor[2] + 1 } ---@type era.m.surrounds.IPosition
  local result = nil ---@type era.m.surrounds.IPosition|nil

  for _, position in ipairs(positions) do
    local comparison = M.compare_positions(current, position) ---@type "<"|">"|"="
    local move_left = comparison == ">" and direction == "left" ---@type boolean
    local move_right = result == nil and comparison == "<" and direction == "right" ---@type boolean
    if move_left or move_right then
      result = position
    end
  end

  result = result or (direction == "right" and positions[1] or positions[#positions])
  M.set_cursor(result.line, result.col)
end

---@param line                          integer
---@return integer
function M.get_line_cols(line)
  local text = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1] or "" ---@type string
  return #text
end

---@param pos                           era.m.surrounds.IPosition
---@return era.m.surrounds.IPosition
function M.position_left(pos)
  if pos.line == 1 and pos.col == 1 then
    return { line = pos.line, col = pos.col }
  end
  if pos.col == 1 then
    return { line = pos.line - 1, col = M.get_line_cols(pos.line - 1) }
  end
  return { line = pos.line, col = pos.col - 1 }
end

---@param pos                           era.m.surrounds.IPosition
---@return era.m.surrounds.IPosition
function M.position_right(pos)
  local cols = M.get_line_cols(pos.line) ---@type integer
  local line_count = vim.api.nvim_buf_line_count(0) ---@type integer
  if pos.line == line_count and pos.col > cols then
    return { line = pos.line, col = cols }
  end
  if pos.col > cols then
    return { line = pos.line + 1, col = 1 }
  end
  return { line = pos.line, col = pos.col + 1 }
end

---@param region                        era.m.surrounds.IRegion
---@return boolean
function M.region_is_empty(region)
  return region.to == nil
end

---@param region                        era.m.surrounds.IRegion
---@param text                          string|string[]
---@return nil
function M.region_replace(region, text)
  local start_row = region.from.line - 1 ---@type integer
  local start_col = region.from.col - 1 ---@type integer
  local end_row = start_row ---@type integer
  local end_col = start_col ---@type integer

  if not M.region_is_empty(region) then
    end_row = region.to.line - 1
    end_col = region.to.col
    if end_row < vim.api.nvim_buf_line_count(0) and M.get_line_cols(end_row + 1) < end_col then
      end_row = end_row + 1
      end_col = 0
    end
  end

  local lines ---@type string[]
  if type(text) == "string" then
    lines = { text }
  else
    lines = text
  end
  if #lines > 0 then
    lines = vim.split(table.concat(lines, "\n"), "\n", { plain = true })
  end

  pcall(vim.api.nvim_buf_set_text, 0, start_row, start_col, end_row, end_col, lines)
end

---@param from_line                     integer
---@param to_line                       integer
---@return string
function M.get_range_indent(from_line, to_line)
  local lines = vim.api.nvim_buf_get_lines(0, from_line - 1, to_line, true) ---@type string[]
  local min_width = math.huge ---@type number
  local result = "" ---@type string
  for _, line in ipairs(lines) do
    local indent = line:match("^(%s*)") or "" ---@type string
    if #indent < min_width and #indent < #line then
      min_width = #indent
      result = indent
    end
  end
  return result
end

---@param direction                     "<"|">"
---@param from_line                     integer
---@param to_line                       integer
---@return nil
function M.shift_indent(direction, from_line, to_line)
  if to_line < from_line then
    return
  end
  vim.cmd(string.format("silent %d,%d%s", from_line, to_line, direction))
end

---@param line                          integer
---@return boolean
function M.is_line_blank(line)
  local text = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1] or "" ---@type string
  return text:match("^%s*$") ~= nil
end

---@param line                          integer
---@return nil
function M.delete_line(line)
  vim.api.nvim_buf_set_lines(0, line - 1, line, false, {})
end

---@param line                          integer                       Insert before this 0-based index
---@param lines                         string[]
---@return nil
function M.insert_lines(line, lines)
  vim.api.nvim_buf_set_lines(0, line, line, false, lines)
end

---@param pair                          era.m.surrounds.IRegionPair
---@return era.m.surrounds.IPosition[]
function M.surrounding_positions(pair)
  local positions = {} ---@type era.m.surrounds.IPosition[]

  ---@param pos                         era.m.surrounds.IPosition|nil
  ---@param correction                  "left"|"right"
  local function append(pos, correction)
    if pos == nil then
      return
    end
    if M.get_line_cols(pos.line) < pos.col and pos.col > 1 then
      pos = correction == "left" and M.position_left(pos) or M.position_right(pos)
    end
    local last = positions[#positions] ---@type era.m.surrounds.IPosition|nil
    if last == nil or last.line ~= pos.line or last.col ~= pos.col then
      positions[#positions + 1] = { line = pos.line, col = pos.col }
    end
  end

  if not M.region_is_empty(pair.left) then
    append(pair.left.from, "right")
    append(pair.left.to, "right")
  end
  if not M.region_is_empty(pair.right) then
    append(pair.right.from, "left")
    append(pair.right.to, "left")
  end
  return positions
end

---@param bufnr                         integer
---@param region                        era.m.surrounds.IRegion
---@return nil
function M.highlight_region(bufnr, region)
  if M.region_is_empty(region) then
    return
  end
  vim.hl.range(
    bufnr,
    NSNR_HIGHLIGHT,
    "IncSearch",
    { region.from.line - 1, region.from.col - 1 },
    { region.to.line - 1, region.to.col }
  )
end

---@param bufnr                         integer
---@param region                        era.m.surrounds.IRegion
---@return nil
function M.clear_region_highlight(bufnr, region)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local to_line = (region.to or region.from).line ---@type integer
  vim.api.nvim_buf_clear_namespace(bufnr, NSNR_HIGHLIGHT, region.from.line - 1, to_line)
end

---@param reference                     era.m.surrounds.IRegion
---@param neighbors                     integer
---@return era.m.surrounds.INeighborhood
function M.get_neighborhood(reference, neighbors)
  local from_line = reference.from.line ---@type integer
  local to_line = (reference.to or reference.from).line ---@type integer
  local line_start = math.max(1, from_line - neighbors) ---@type integer
  local line_end = math.min(vim.api.nvim_buf_line_count(0), to_line + neighbors) ---@type integer
  local lines = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false) ---@type string[]
  for index, line in ipairs(lines) do
    lines[index] = line .. "\n"
  end
  local text = table.concat(lines) ---@type string

  ---@param pos                         era.m.surrounds.IPosition
  ---@return integer
  local function position_to_offset(pos)
    local line = line_start ---@type integer
    local offset = 0 ---@type integer
    while line < pos.line do
      offset = offset + #lines[line - line_start + 1]
      line = line + 1
    end
    return offset + pos.col
  end

  ---@param offset                      integer
  ---@return era.m.surrounds.IPosition
  local function offset_to_position(offset)
    local line = 1 ---@type integer
    local line_offset = 0 ---@type integer
    while line <= #lines and line_offset + #lines[line] < offset do
      line_offset = line_offset + #lines[line]
      line = line + 1
    end
    return { line = line_start + line - 1, col = offset - line_offset }
  end

  ---@param region                      era.m.surrounds.IRegion
  ---@return era.m.surrounds.ISpan
  local function region_to_span(region)
    local is_empty = region.to == nil ---@type boolean
    local target = region.to or region.from ---@type era.m.surrounds.IPosition
    return {
      from = position_to_offset(region.from),
      to = position_to_offset(target) + (is_empty and 0 or 1),
    }
  end

  ---@param span                        era.m.surrounds.ISpan
  ---@return era.m.surrounds.IRegion
  local function span_to_region(span)
    local region = { from = offset_to_position(span.from) } ---@type era.m.surrounds.IRegion
    if span.from < span.to then
      region.to = offset_to_position(span.to - 1)
    end
    return region
  end

  return {
    n_neighbors = neighbors,
    text = text,
    lines = lines,
    region_to_span = region_to_span,
    span_to_region = span_to_region,
  }
end

return M
