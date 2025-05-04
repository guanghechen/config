local __module_name__ = "fml.dressing.winsep" ---@type string

local Line = require("fml.dressing.winsep.line")

---@class fml.dressing.winsep.IScheduleContext
---@field public winnr                  integer|nil

---@class fml.dressing.Winsep
---@field public left                   fml.dressing.winsep.Line
---@field public top                    fml.dressing.winsep.Line
---@field public right                  fml.dressing.winsep.Line
---@field public bottom                 fml.dressing.winsep.Line
---@field public hide                   fun(self: fml.dressing.Winsep):nil
---@field public show                   fun(self: fml.dressing.Winsep, winnr: integer):nil
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
}

---@type eve.std.collection.Scheduler
local scheduler = eve.std.Scheduler.new({
  name = __module_name__,
  mode = "throttle",
  delay = 64,
  timeout = 0,
  silent = eve.std.fn.falsy,
  value = eve.std.Observable.from_value(true),
  task = function(_, context)
    local enabled = eve.state.flight.dressing_winsep:snapshot() ---@type boolean
    if not enabled then
      return
    end

    context = context or {} ---@type fml.dressing.winsep.IScheduleContext
    local winnr = context.winnr ---@type integer|nil
    if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
      return
    end

    winsep:show(winnr)
  end,
})

vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "SessionLoadPost" }, {
  group = eve.nvim.augroup("winsep_on_resize"),
  callback = function()
    local winnr = eve.status.winnr_fixed:snapshot() ---@type integer|nil
    local context = { winnr = winnr } ---@type fml.dressing.winsep.IScheduleContext
    scheduler:schedule({ context = context })
  end,
})

eve.state.observe({ eve.state.flight.dressing_winsep }, function()
  local enabled = eve.state.flight.dressing_winsep:snapshot() ---@type boolean
  if not enabled then
    winsep:hide()
    return
  end

  local winnr = eve.status.winnr_fixed:snapshot() ---@type integer|nil
  local context = { winnr = winnr } ---@type fml.dressing.winsep.IScheduleContext
  scheduler:schedule({ context = context })
end, false)

eve.state.observe({ eve.status.winnr_fixed }, function()
  local winnr = eve.status.winnr_fixed:snapshot() ---@type integer|nil
  local context = { winnr = winnr } ---@type fml.dressing.winsep.IScheduleContext
  scheduler:schedule({ context = context })
end, false)
