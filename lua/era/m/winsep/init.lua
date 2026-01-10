local Line = require("era.m.winsep.line")

---@class era.m.winsep.Winsep
---@field public left                   era.m.winsep.Line
---@field public top                    era.m.winsep.Line
---@field public right                  era.m.winsep.Line
---@field public bottom                 era.m.winsep.Line
---@field public hide                   fun(self: era.m.winsep.Winsep):nil
---@field public show                   fun(self: era.m.winsep.Winsep, winnr: integer):nil
local winsep = {
  left = Line.new({ direction = "h" }),
  top = Line.new({ direction = "k" }),
  right = Line.new({ direction = "l" }),
  bottom = Line.new({ direction = "j" }),
  hide = function(self)
    self.left:hide()
    self.top:hide()
    self.right:hide()
    self.bottom:hide()
  end,
  show = function(self, winnr)
    local width = vim.fn.winwidth(winnr) - 1 ---@type integer
    local height = vim.fn.winheight(winnr) ---@type integer
    local win_pos = vim.api.nvim_win_get_position(winnr) ---@type integer[]
    local row = win_pos[1] ---@type integer
    local col = win_pos[2] ---@type integer

    local fn_winnr ---@type integer
    local h_exist ---@type boolean
    local k_exist ---@type boolean
    local l_exist ---@type boolean
    local j_exist ---@type boolean

    vim.api.nvim_win_call(winnr, function()
      fn_winnr = vim.fn.winnr() ---@type integer
      h_exist = fn_winnr ~= vim.fn.winnr("h") ---@type boolean
      k_exist = fn_winnr ~= vim.fn.winnr("k") ---@type boolean
      l_exist = fn_winnr ~= vim.fn.winnr("l") ---@type boolean
      j_exist = fn_winnr ~= vim.fn.winnr("j") ---@type boolean
    end)

    if vim.api.nvim_get_option_value("winbar", { win = winnr }) == "" then
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
}

---@class era.m.winsep
---@field public dressing               fun(): nil
---@field public Line                   era.m.winsep.Line
---@field public Winsep                 era.m.winsep.Winsep
local M = {
  Line = Line,
  Winsep = winsep,
}

---@return nil
function M.dressing()
  local refresh_debounced = stl.timer.debounce(function(winnr)
    local enabled = dot.context.flight.dressing_winsep:snapshot() ---@type boolean
    if not enabled then
      winsep:hide()
      return
    end

    if winnr ~= nil and winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
      winsep:show(winnr)
    end
  end, 32)

  stl.fn.observe({ dot.context.flight.dressing_winsep }, function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr_fixed = dot.tab.retrieve_winnr_fixed(tabnr) ---@type integer|nil
    refresh_debounced(winnr_fixed)
  end, true)

  vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "SessionLoadPost" }, {
    group = stl.nvim.fn.augroup("era.winsep_on_resize"),
    callback = function()
      vim.schedule(function()
        local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
        local winnr_fixed = dot.tab.retrieve_winnr_fixed(tabnr) ---@type integer|nil
        refresh_debounced(winnr_fixed)
      end)
    end,
  })

  vim.api.nvim_create_autocmd("WinEnter", {
    group = stl.nvim.fn.augroup("era.winsep_on_WinEnter"),
    callback = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      if stl.nvim.win.is_fixed(winnr) then
        refresh_debounced(winnr)
      end
    end,
  })
end

return M
