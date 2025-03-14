local Line = require("fml.dressing.winsep.line")

---@type fml.dressing.Winsep
local float_winsep = {
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
  ---@diagnostic disable-next-line: unused-local
  should_show = function(self, winnr)
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    return eve.filetype.is_winsep_float(filetype)
  end,
}

return float_winsep
