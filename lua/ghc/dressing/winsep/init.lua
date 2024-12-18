local constant = require("eve.builtin.constant")
local checks = require("eve.builtin.checks")
local state = require("eve.state")
local Line = require("ghc.dressing.winsep.line")

---@class ghc.dressing.Winsep
---@field public left                   ghc.dressing.winsep.Line
---@field public top                    ghc.dressing.winsep.Line
---@field public right                  ghc.dressing.winsep.Line
---@field public bottom                 ghc.dressing.winsep.Line
---@field public show                   fun(self: ghc.dressing.Winsep):nil
---@field public hide                   fun(self: ghc.dressing.Winsep):nil
---@field public should_show            fun(self: ghc.dressing.Winsep, winnr: integer):boolean

---@type ghc.dressing.Winsep
local fixed_winsep = {
  left = Line.new({ direction = "h", zindex = 1, winhighlight = "NormalFloat:f_winsep_fixed" }),
  top = Line.new({ direction = "k", zindex = 1, winhighlight = "NormalFloat:f_winsep_fixed" }),
  right = Line.new({ direction = "l", zindex = 1, winhighlight = "NormalFloat:f_winsep_fixed" }),
  bottom = Line.new({ direction = "j", zindex = 1, winhighlight = "NormalFloat:f_winsep_fixed" }),
  show = function(self)
    local winnr = vim.api.nvim_get_current_win() ---@type integer
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
  hide = function(self)
    self.left:hide()
    self.top:hide()
    self.right:hide()
    self.bottom:hide()
  end,
  ---@diagnostic disable-next-line: unused-local
  should_show = function(self, winnr)
    local enabled = state.flight.dressing_winsep_fixed:snapshot() ---@type boolean
    return enabled and not checks.is_win_floating(winnr)
  end,
}

---@type ghc.dressing.Winsep
local float_winsep = {
  left = Line.new({ direction = "h", zindex = 99, winhighlight = "NormalFloat:f_winsep_float" }),
  top = Line.new({ direction = "k", zindex = 99, winhighlight = "NormalFloat:f_winsep_float" }),
  right = Line.new({ direction = "l", zindex = 99, winhighlight = "NormalFloat:f_winsep_float" }),
  bottom = Line.new({ direction = "j", zindex = 99, winhighlight = "NormalFloat:f_winsep_float" }),
  show = function(self)
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local win_config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
    local row = win_config.row ---@type integer
    local col = win_config.col ---@type integer
    local width = win_config.width ---@type integer
    local height = win_config.height ---@type integer

    self.left:move(row, col, height)
    self.left:show()

    self.top:move(row, col, width)
    self.top:show()

    self.right:move(row, col + width + 1, height)
    self.right:show()

    self.bottom:move(row + height + 1, col, width)
    self.bottom:show()
  end,
  hide = function(self)
    self.left:hide()
    self.top:hide()
    self.right:hide()
    self.bottom:hide()
  end,
  ---@diagnostic disable-next-line: unused-local
  should_show = function(self, winnr)
    local enabled = state.flight.dressing_winsep_float:snapshot() ---@type boolean
    if not enabled or not checks.is_win_floating(winnr) then
      return false
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.bo[bufnr].filetype ---@type string
    if filetype ~= constant.FT_SEARCH_INPUT and filetype ~= constant.FT_SEARCH_PREVIEW then
      return false
    end

    local widget = eve.widgets.get_current_widget() ---@type eve.t.ux.IWidget|nil
    if widget == nil then
      return false
    end

    ---@cast widget fml.t.ux.search.ISearch
    return widget.get_winnr_preview ~= nil and widget:get_winnr_preview() ~= nil
  end,
}

vim.api.nvim_create_autocmd({ "WinEnter", "WinResized", "SessionLoadPost" }, {
  group = eve.nvim.augroup("winsep_refresh"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if fixed_winsep:should_show(winnr) then
      fixed_winsep:show()
    end
    if float_winsep:should_show(winnr) then
      float_winsep:show()
    else
      float_winsep:hide()
    end
  end,
})

eve.mvc.observe({ state.flight.dressing_winsep_fixed }, function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if fixed_winsep:should_show(winnr) then
    fixed_winsep:show()
  else
    fixed_winsep:hide()
  end
end)

eve.mvc.observe({ state.flight.dressing_winsep_float }, function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if float_winsep:should_show(winnr) then
    float_winsep:show()
  else
    float_winsep:hide()
  end
end)
