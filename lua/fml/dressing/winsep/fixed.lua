local Line = require("fml.dressing.winsep.line")

---@type fml.dressing.Winsep
local fixed_winsep = {
  left = Line.new({ direction = "h", zindex = 1, winhighlight = "NormalFloat:f_winsep_fixed" }),
  top = Line.new({ direction = "k", zindex = 1, winhighlight = "NormalFloat:f_winsep_fixed" }),
  right = Line.new({ direction = "l", zindex = 1, winhighlight = "NormalFloat:f_winsep_fixed" }),
  bottom = Line.new({ direction = "j", zindex = 1, winhighlight = "NormalFloat:f_winsep_fixed" }),
  hide = function(self)
    self.left:hide()
    self.top:hide()
    self.right:hide()
    self.bottom:hide()
  end,
  show = function(self, winnr)
    local win_pos = vim.api.nvim_win_get_position(winnr) ---@type integer[]
    local row = win_pos[1] ---@type integer
    local col = win_pos[2] ---@type integer
    local width = vim.fn.winwidth(0) - 1 ---@type integer
    local height = vim.fn.winheight(0) ---@type integer

    local fn_winnr = vim.fn.winnr() ---@type integer
    local h_exist = fn_winnr ~= vim.fn.winnr("h") ---@type boolean
    local k_exist = fn_winnr ~= vim.fn.winnr("k") ---@type boolean
    local l_exist = fn_winnr ~= vim.fn.winnr("l") ---@type boolean
    local j_exist = fn_winnr ~= vim.fn.winnr("j") ---@type boolean

    if vim.wo[winnr].winbar == "" then
      height = height - 1
    end

    if h_exist then
      col = col - 1
    end

    if k_exist then
      row = row - 1
    end

    if h_exist and l_exist then
      width = width + 1
    end

    if k_exist and j_exist then
      height = height + 1
    end

    if not k_exist and not j_exist then
      height = height - 1
    end

    if h_exist then
      self.left:move(row, col, height)
      self.left:show()
    else
      self.left:hide()
    end

    if k_exist then
      self.top:move(row, col, width)
      self.top:show()
    else
      self.top:hide()
    end

    if l_exist then
      self.right:move(row, col + width + 1, height)
      self.right:show()
    else
      self.right:hide()
    end

    if j_exist then
      self.bottom:move(row + height + 1, col, width)
      self.bottom:show()
    else
      self.bottom:hide()
    end
  end,
  ---@diagnostic disable-next-line: unused-local
  should_show = function(self, winnr)
    return not eve.editor.is_win_floating(winnr)
  end,
}

return fixed_winsep
