---@class fml.std.box
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
---@param restriction                   fml.types.ui.IBoxRestriction
---@return fml.ui.types.IBoxDimension
function M.measure(width, height, restriction)
  local rows = restriction.rows ---@type integer
  local cols = restriction.cols ---@type integer
  local max_width = M.flat(restriction.max_width or 1, cols) ---@type integer
  local max_height = M.flat(restriction.max_height or 1, rows) ---@type integer
  local min_width = M.flat(restriction.min_width or 0, cols) ---@type integer
  local min_height = M.flat(restriction.min_height or 0, rows) ---@type integer

  max_width = math.max(10, math.min(cols, max_width)) ---@type integer
  max_height = math.max(10, math.min(rows, max_height)) ---@type integer
  min_width = math.max(1, math.min(max_width, min_width)) ---@type integer
  min_height = math.max(1, math.min(max_height, min_height)) ---@type integer
  width = math.max(min_width, math.min(max_width, M.flat(width, cols))) ---@type integer
  height = math.max(min_height, math.min(max_height, M.flat(height, rows))) ---@type integer

  if restriction.row ~= nil and restriction.col ~= nil then
    local row = M.flat(restriction.row, rows) ---@type integer
    local col = M.flat(restriction.col, cols) ---@type integer
    row = math.max(1, math.min(rows - height + 1, row)) ---@type integer
    col = math.max(0, math.min(cols - width, col)) ---@type integer

    ---@type fml.ui.types.IBoxDimension
    return { row = row, col = col, width = width, height = height }
  end

  local position = restriction.position ---@type fml.enums.BoxPosition
  if position == "cursor" then
    if restriction.cursor_row ~= nil and restriction.cursor_col ~= nil then
      local row = restriction.cursor_row + 1 ---@type integer
      local col = restriction.cursor_col - math.floor(width / 2) ---@type integer
      row = math.max(1, math.min(rows - height + 1, row)) ---@type integer
      col = math.max(0, math.min(cols - width, col)) ---@type integer

      ---@type fml.ui.types.IBoxDimension
      return { row = row, col = col, width = width, height = height }
    end
  end

  local row = math.floor((rows - height) / 2) - 1 ---@type integer
  local col = math.floor((cols - width) / 2) ---@type integer
  row = math.max(1, math.min(rows - height + 1, row)) ---@type integer
  col = math.max(0, math.min(cols - width, col)) ---@type integer

  ---@type fml.ui.types.IBoxDimension
  return { row = row, col = col, width = width, height = height }
end

return M
