---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.ui_grid" ---@type string

local M = {}
M.__index = M

---@param ui                            __test__.support.UI
---@param on_flush                      ?fun(grid: table): nil
---@return table
function M.new(ui, on_flush)
  local self = setmetatable({ grids = {}, highlights = {}, flushes = 0 }, M)
  ui.on_redraw = function(events)
    for _, event in ipairs(events) do
      local name = event[1]
      for index = 2, #event do
        local value = event[index]
        if name == "grid_resize" or name == "grid_clear" then
          local old = self.grids[value[1]]
          local width, height = value[2] or old.width, value[3] or old.height
          local grid = { width = width, height = height, rows = {} }
          for row = 1, height do
            grid.rows[row] = {}
            for col = 1, width do
              grid.rows[row][col] = { " ", 0 }
            end
          end
          self.grids[value[1]] = grid
        elseif name == "grid_line" then
          local grid, row, col, highlight = self.grids[value[1]], value[2] + 1, value[3] + 1, 0
          for _, cell in ipairs(value[4]) do
            highlight = cell[2] or highlight
            for _ = 1, cell[3] or 1 do
              grid.rows[row][col] = { cell[1], highlight }
              col = col + 1
            end
          end
        elseif name == "grid_scroll" then
          local grid, top, bottom, left, right, rows, cols = unpack(value)
          grid = self.grids[grid]
          local before = vim.deepcopy(grid.rows)
          for row = top + 1, bottom do
            for col = left + 1, right do
              local from_row, from_col = row + rows, col + cols
              grid.rows[row][col] = from_row > top
                  and from_row <= bottom
                  and from_col > left
                  and from_col <= right
                  and before[from_row][from_col]
                or { " ", 0 }
            end
          end
        elseif name == "hl_attr_define" then
          self.highlights[value[1]] = value[2]
        elseif name == "grid_cursor_goto" then
          self.cursor = value
        elseif name == "flush" then
          self.flushes = self.flushes + 1
          if on_flush then
            on_flush(self)
          end
        end
      end
    end
  end
  return self
end

---@param text                          string
---@return table|nil
function M:find(text)
  for gridnr, grid in pairs(self.grids) do
    for row, cells in ipairs(grid.rows) do
      for col = 1, grid.width - #text + 1 do
        if cells[col][1] == text:sub(1, 1) then
          local equal = true
          for offset = 1, #text - 1 do
            if cells[col + offset][1] ~= text:sub(offset + 1, offset + 1) then
              equal = false
              break
            end
          end
          if equal then
            return { grid = gridnr, row = row - 1, col = col - 1, highlight = self.highlights[cells[col][2]] or {} }
          end
        end
      end
    end
  end
  return nil
end

return M
