---@class fml.std.box
local M = {}

---@class fml.std.box.IMeasureParams
---@field public position                fml.enums.BoxPosition
---@field public width                   number
---@field public height                  number
---@field public row                     ?number
---@field public col                     ?number
---@field public cursor_row              ?integer
---@field public cursor_col              ?integer
---@field public max_width               ?number
---@field public max_height              ?number
---@field public min_width               ?number
---@field public min_height              ?number

---@class fml.types.IRect
---@field public row                    integer
---@field public col                    integer
---@field public width                  integer
---@field public height                 integer

---@param size                          number
---@param full_size                     integer
---@return integer
function M.flat(size, full_size)
  if size <= 1 then
    return math.floor(size * full_size)
  end
  return size > 0 and math.floor(size) or 0
end

---@param params                        fml.std.box.IMeasureParams
---@return fml.types.IRect
function M.measure(params)
  local full_width = vim.o.columns ---@type integer
  local full_height = vim.o.lines ---@type integer

  local max_width = M.flat(params.max_width or 1, full_width) ---@type integer
  local max_height = M.flat(params.max_height or 1, full_height) ---@type integer
  local min_width = M.flat(params.min_width or 0, full_width) ---@type integer
  local min_height = M.flat(params.min_height or 0, full_height) ---@type integer
  local width = M.flat(params.width, full_width) ---@type integer
  local height = M.flat(params.height, full_height) ---@type integer

  max_width = math.max(10, math.min(full_width, max_width))
  max_height = math.max(10, math.min(full_height, max_height))
  min_width = math.max(1, math.min(max_width, min_width))
  min_height = math.max(1, math.min(max_height, min_height))
  width = math.max(min_width, math.min(max_width, width)) ---@type integer
  height = math.max(min_height, math.min(max_height, height)) ---@type integer

  local row = 0 ---@type integer
  local col = 0 ---@type integer
  local position = params.position ---@type fml.enums.BoxPosition
  if position == "center" then
    row = math.floor((full_height - height) / 2) ---@type integer
    col = math.floor((full_width - width) / 2) ---@type integer
  else
    local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
    local cursor_row = params.cursor_row or cursor[1] ---@type integer
    local cursor_col = params.cursor_col or cursor[2] ---@type integer
    local top_distance = cursor_row - vim.fn.line("w0") ---@type integer
    local left_distance = cursor_col - vim.fn.virtcol("w0") + 1 ---@type integer
    local bottom_distance = full_height - top_distance ---@type integer
    local right_distance = full_width - left_distance ---@type integer

    row = (top_distance > height or bottom_distance <= height) and cursor_row - height - 1 or cursor_row + 1 ---@type integer
    col = (right_distance > width or left_distance <= width) and cursor_col + 1 or cursor_col - width - 1 ---@type integer
  end

  row = M.flat(params.row or row, full_height)
  col = M.flat(params.col or col, full_width)
  local rect = { row = row, col = col, width = width, height = height } ---@type fml.types.IRect
  return rect
end

return M
