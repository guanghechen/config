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
  mode = "debounce",
  delay = 32,
  timeout = 0,
  silent = eve.std.fn.falsy,
  value = eve.std.Observable.from_value(true),
  task = function(_, context)
    local enabled = eve.context.flight.dressing_winsep:snapshot() ---@type boolean
    if not enabled then
      winsep:hide()
      return
    end

    context = context or {} ---@type fml.dressing.winsep.IScheduleContext
    local winnr = context.winnr ---@type integer|nil
    if winnr ~= nil and winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
      winsep:show(winnr)
    end
  end,
})

eve.fn.observe({ eve.context.flight.dressing_winsep }, function()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_fixed = eve.tab.retrieve_winnr_fixed(tabnr) ---@type integer|nil
  local context = { winnr = winnr_fixed } ---@type fml.dressing.winsep.IScheduleContext
  scheduler:schedule({ context = context })
end, true)

vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "SessionLoadPost" }, {
  group = eve.nvim.augroup("winsep_on_resize"),
  callback = function()
    vim.schedule(function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_fixed = eve.tab.retrieve_winnr_fixed(tabnr) ---@type integer|nil
      local context = { winnr = winnr_fixed } ---@type fml.dressing.winsep.IScheduleContext
      scheduler:schedule({ context = context })
    end)
  end,
})

vim.api.nvim_create_autocmd("WinEnter", {
  group = eve.nvim.augroup("winsep_on_WinEnter"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if eve.win.is_fixed(winnr) then
      local context = { winnr = winnr } ---@type fml.dressing.winsep.IScheduleContext
      scheduler:schedule({ context = context })
    end
  end,
})
