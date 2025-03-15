local Line = require("fml.dressing.winsep.line")

---@class fml.dressing.winsep.float
---@field public winsep                 fml.dressing.Winsep
---@field public scheduler              eve.collection.Scheduler
local M = {}

---@type fml.dressing.Winsep
M.winsep = {
  left = Line.new({ direction = "h", zindex = 99, winhighlight = "NormalFloat:f_winsep_float" }),
  top = Line.new({ direction = "k", zindex = 99, winhighlight = "NormalFloat:f_winsep_float" }),
  right = Line.new({ direction = "l", zindex = 99, winhighlight = "NormalFloat:f_winsep_float" }),
  bottom = Line.new({ direction = "j", zindex = 99, winhighlight = "NormalFloat:f_winsep_float" }),
  hide = function(self)
    self.left:hide()
    self.top:hide()
    self.right:hide()
    self.bottom:hide()
  end,
  show = function(self, winnr)
    local win_config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    local row = win_config.row ---@type integer
    local col = win_config.col ---@type integer
    local width = win_config.width ---@type integer
    local height = win_config.height ---@type integer

    self.left:move(row, col, height)
    self.left:show()

    -- self.top:move(row, col, width)
    -- self.top:show()

    self.right:move(row, col + width + 1, height)
    self.right:show()

    self.bottom:move(row + height + 1, col, width)
    self.bottom:show()
  end,
}

M.scheduler = eve.col.Scheduler.new({
  name = "winsep_refresh float",
  delay = 200,
  silent = function()
    local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  task = function(callback)
    if eve.state.flight.dressing_winsep_float:snapshot() then
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local filetype = vim.bo[bufnr].filetype ---@type string
      if eve.filetype.is_winsep_float(filetype) then
        M.winsep:show(winnr)
      else
        M.winsep:hide()
      end
    end
    callback("fulfilled")
  end,
})

return M
