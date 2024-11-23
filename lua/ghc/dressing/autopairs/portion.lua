---@class ghc.dressing.autopairs.IPos
---@field public row                    integer
---@field public col                    integer

---@class ghc.dressing.autopairs.IPair
---@field public left                   ghc.dressing.autopairs.IPos
---@field public right                  ghc.dressing.autopairs.IPos

---@class ghc.dressing.autopairs.IViewport
---@field public top                    integer
---@field public bot                    integer

---@class ghc.dressing.autopairs.Portion
---@field private viewport              ghc.dressing.autopairs.IViewport Visible viewport in `(top, bottom)` format.
---@field private cursor                ghc.dressing.autopairs.IPos Cursor position in `(row, col)` format.
---@field private lines                 string[] Lines inside `viewport`.
local M = {}

---@param winnr                         integer Window to take the visible portion of.
---@param limit                         integer Maximum amount of lines around the cursor to be processed.
---@return ghc.dressing.autopairs.Portion
function M.new(winnr, limit)
  local self = setmetatable({}, { __index = M })

  local win_cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]

  ---@type ghc.dressing.autopairs.IPos
  local cursor = { row = win_cursor[1], col = win_cursor[2] + 1 }

  ---@type ghc.dressing.autopairs.IViewport
  local viewport = {
    top = vim.fn.line("w0", winnr),
    bot = vim.fn.line("w$", winnr),
  }

  if cursor.row - viewport.top > limit then
    viewport.top = cursor.row - limit
  end

  if viewport.bot - cursor.row > limit then
    viewport.bot = self.cursor.row + limit
  end

  ---@type string[]
  local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winnr), viewport.top - 1, viewport.bot, true)

  self.cursor = cursor
  self.viewport = viewport
  self.lines = lines
  return self
end

---@return ghc.dressing.autopairs.IPos
function M:get_cursor()
  ---@type ghc.dressing.autopairs.IPos
  local cursor = {
    row = self.cursor.row,
    col = self.cursor.col,
  }
  return cursor
end

---@return integer
function M:get_top()
  return self.viewport.top
end

---@return integer
function M:get_bottom()
  return self.viewport.bot
end

---@private
---@param row                           integer
---@return string
function M:get_line(row)
  local index = row - self.viewport.top + 1 ---@type integer
  return self.lines[index]
end

---Get the character under the cursor.
---
---@return string
function M:get_current_char()
  local cursor = self.cursor ---@type ghc.dressing.autopairs.IPos
  return self:get_line(cursor.row):sub(cursor.col, cursor.col)
end

---@return fun(): ghc.dressing.autopairs.IPos|nil, string
function M:iter()
  local cursor = self:get_cursor() ---@type ghc.dressing.autopairs.IPos

  return function()
    local line = self:get_line(cursor.row) ---@type string
    local viewport = self.viewport ---@type ghc.dressing.autopairs.IViewport

    cursor.col = cursor.col + 1

    if cursor.col > #line then
      cursor.row = cursor.row + 1
      if cursor.row > viewport.bot then
        return nil, ""
      end

      line = self:get_line(cursor.row)
      cursor.col = 1
    end

    return cursor, line:sub(cursor.col, cursor.col)
  end
end

---@return fun(): ghc.dressing.autopairs.IPos|nil, string
function M:iter_reverse()
  local cursor = self:get_cursor() ---@type ghc.dressing.autopairs.IPos

  return function()
    local line = self:get_line(cursor.row) ---@type string
    local viewport = self.viewport ---@type ghc.dressing.autopairs.IViewport

    cursor.col = cursor.col - 1

    if cursor.col < 1 then
      cursor.row = cursor.row - 1
      if cursor.row < viewport.top then
        return nil, ""
      end

      line = self:get_line(cursor.row)
      cursor.col = #line
    end

    return cursor, line:sub(cursor.col, cursor.col)
  end
end

return M
