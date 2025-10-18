---@class eve.builtin.box.IDimension
---@field public row                    integer
---@field public col                    integer
---@field public width                  integer
---@field public height                 integer

---@class eve.builtin.box.IRestriction
---@field public position               std.e.BoxPosition
---@field public rows                   integer
---@field public cols                   integer
---@field public row                    ?number
---@field public col                    ?number
---@field public cursor_row             ?integer
---@field public cursor_col             ?integer
---@field public max_width              ?number
---@field public max_height             ?number
---@field public min_width              ?number
---@field public min_height             ?number

---@class eve.builtin.box
local M = {}

---@param size                          number
---@param full_size                     integer
---@return integer
function M.flat(size, full_size)
  if size <= 0 then
    return 0
  end

  if size <= 1 then
    return math.floor(size * full_size)
  end

  return math.floor(size)
end

---@param width                         integer
---@param height                        integer
---@param restriction                   eve.builtin.box.IRestriction
---@return eve.builtin.box.IDimension
function M.measure(width, height, restriction)
  local rows = restriction.rows ---@type integer
  local cols = restriction.cols ---@type integer
  local max_width = M.flat(restriction.max_width or 1, cols) ---@type integer
  local max_height = M.flat(restriction.max_height or 1, rows) ---@type integer
  local min_width = M.flat(restriction.min_width or 0, cols) ---@type integer
  local min_height = M.flat(restriction.min_height or 0, rows) ---@type integer

  max_width = math.max(10, math.min(cols, max_width)) ---@type integer
  max_height = math.max(1, math.min(rows, max_height)) ---@type integer
  min_width = math.max(10, math.min(max_width, min_width)) ---@type integer
  min_height = math.max(1, math.min(max_height, min_height)) ---@type integer
  width = math.max(min_width, math.min(max_width, M.flat(width, cols))) ---@type integer
  height = math.max(min_height, math.min(max_height, M.flat(height, rows))) ---@type integer

  if restriction.row ~= nil and restriction.col ~= nil then
    local row = M.flat(restriction.row, rows) ---@type integer
    local col = M.flat(restriction.col, cols) ---@type integer
    row = math.max(1, math.min(rows - height + 1, row)) ---@type integer
    col = math.max(0, math.min(cols - width, col)) ---@type integer

    ---@type eve.builtin.box.IDimension
    return { row = row, col = col, width = width, height = height }
  end

  local position = restriction.position ---@type std.e.BoxPosition
  if position == "cursor" then
    if restriction.cursor_row ~= nil and restriction.cursor_col ~= nil then
      local row = restriction.cursor_row + 1 ---@type integer
      local col = restriction.cursor_col - math.floor(width / 2) ---@type integer
      row = math.max(1, math.min(rows - height + 1, row)) ---@type integer
      col = math.max(0, math.min(cols - width, col)) ---@type integer

      ---@type eve.builtin.box.IDimension
      return { row = row, col = col, width = width, height = height }
    end
  end

  local row = restriction.row and M.flat(restriction.row, rows) or math.floor((rows - height) / 2) - 1 ---@type integer
  local col = restriction.col and M.flat(restriction.col, cols) or math.floor((cols - width) / 2) ---@type integer
  row = math.max(1, math.min(rows - height + 1, row)) ---@type integer
  col = math.max(0, math.min(cols - width, col)) ---@type integer

  ---@type eve.builtin.box.IDimension
  return { row = row, col = col, width = width, height = height }
end

---@param border                        string|table|nil
---@return integer left
---@return integer right
---@return integer top
---@return integer bottom
function M.resolve_border_extents(border)
  local left = 0 ---@type integer
  local right = 0 ---@type integer
  local top = 0 ---@type integer
  local bottom = 0 ---@type integer

  local function has_border(entry)
    if entry == nil then
      return false
    end
    if type(entry) == "string" then
      return entry ~= ""
    end
    if type(entry) == "boolean" then
      return entry
    end
    if type(entry) == "table" then
      local text = entry[1] ---@type unknown
      if type(text) == "string" then
        return text ~= ""
      end
      if type(text) == "number" then
        return text ~= 0
      end
      return text == true
    end
    return false
  end

  if border == nil or border == "none" then
    return left, right, top, bottom
  end

  if type(border) == "string" then
    if border == "shadow" then
      right = 1
      bottom = 1
      return left, right, top, bottom
    end
    left = 1
    right = 1
    top = 1
    bottom = 1
    return left, right, top, bottom
  end

  ---@cast border table
  ---@type table<integer|string, unknown>
  local border_tbl = border

  local top_entry = border_tbl[2] or border_tbl["top"] ---@type unknown
  local right_entry = border_tbl[4] or border_tbl["right"] ---@type unknown
  local bottom_entry = border_tbl[6] or border_tbl["bottom"] ---@type unknown
  local left_entry = border_tbl[8] or border_tbl["left"] ---@type unknown

  if has_border(left_entry) then
    left = 1
  end
  if has_border(right_entry) then
    right = 1
  end
  if has_border(top_entry) then
    top = 1
  end
  if has_border(bottom_entry) then
    bottom = 1
  end

  return left, right, top, bottom
end

---@class eve.builtin.box.FitEditorOpts
---@field public cols                   integer|nil
---@field public rows                   integer|nil

---@param width                         integer
---@param height                        integer
---@param border                        string|table|nil
---@param opts                          eve.builtin.box.FitEditorOpts|nil
---@return integer
---@return integer
function M.fit_editor(width, height, border, opts)
  opts = opts or {} ---@type eve.builtin.box.FitEditorOpts

  local cols = opts.cols or vim.o.columns ---@type integer
  local rows = opts.rows or vim.o.lines ---@type integer

  local left, right, top, bottom = M.resolve_border_extents(border) ---@type integer, integer, integer, integer
  local max_width = math.max(1, cols - (left + right)) ---@type integer
  local max_height = math.max(1, rows - (top + bottom)) ---@type integer

  width = math.max(1, math.min(max_width, width)) ---@type integer
  height = math.max(1, math.min(max_height, height)) ---@type integer

  return width, height
end

return M
