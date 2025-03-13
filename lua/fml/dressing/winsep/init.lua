local fn = require("eve.builtin.fn")
local Scheduler = require("eve.collection.scheduler")
local state = require("eve.state")

local fixed_winsep = require("fml.dressing.winsep.fixed")
local float_winsep = require("fml.dressing.winsep.float")

---@class fml.dressing.Winsep
---@field public left                   fml.dressing.winsep.Line
---@field public top                    fml.dressing.winsep.Line
---@field public right                  fml.dressing.winsep.Line
---@field public bottom                 fml.dressing.winsep.Line
---@field public hide                   fun(self: fml.dressing.Winsep):nil
---@field public show                   fun(self: fml.dressing.Winsep, winnr: integer):nil
---@field public should_show            fun(self: fml.dressing.Winsep, winnr: integer):boolean

local refresh_fixed = Scheduler.new({
  name = "winsep_refresh fixed",
  delay = 50,
  silent = function()
    local devmode = state.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  task = function(callback)
    if state.flight.dressing_winsep_fixed:snapshot() then
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      if fixed_winsep:should_show(winnr) then
        fixed_winsep:show(winnr)
      end
    end
    callback("fulfilled")
  end,
})

local refresh_float = Scheduler.new({
  name = "winsep_refresh float",
  delay = 200,
  silent = function()
    local devmode = state.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  task = function(callback)
    if state.flight.dressing_winsep_float:snapshot() then
      local winnr = vim.api.nvim_get_current_win() ---@type integer
      if float_winsep:should_show(winnr) then
        float_winsep:show(winnr)
      else
        float_winsep:hide()
      end
    end
    callback("fulfilled")
  end,
})

vim.api.nvim_create_autocmd({ "WinEnter", "WinResized", "SessionLoadPost" }, {
  group = eve.std.nvim.augroup("winsep_refresh"),
  callback = function()
    refresh_fixed:schedule()
    refresh_float:schedule()
  end,
})

state.observe({ state.flight.dressing_winsep_fixed }, function()
  local enabled = state.flight.dressing_winsep_fixed:snapshot() ---@type boolean
  if enabled then
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if fixed_winsep:should_show(winnr) then
      fixed_winsep:show(winnr)
    end
  else
    fixed_winsep:hide()
  end
end)

state.observe({ state.flight.dressing_winsep_float }, function()
  local enabled = state.flight.dressing_winsep_float:snapshot() ---@type boolean
  if enabled then
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if float_winsep:should_show(winnr) then
      float_winsep:show(winnr)
    end
  else
    float_winsep:hide()
  end
end)
