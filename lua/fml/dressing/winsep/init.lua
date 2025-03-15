local fixed_winsep = require("fml.dressing.winsep.fixed")
local float_winsep = require("fml.dressing.winsep.float")

---@class fml.dressing.Winsep
---@field public left                   fml.dressing.winsep.Line
---@field public top                    fml.dressing.winsep.Line
---@field public right                  fml.dressing.winsep.Line
---@field public bottom                 fml.dressing.winsep.Line
---@field public hide                   fun(self: fml.dressing.Winsep):nil
---@field public show                   fun(self: fml.dressing.Winsep, winnr: integer):nil

vim.api.nvim_create_autocmd({ "VimResized", "WinResized", "SessionLoadPost" }, {
  group = eve.nvim.augroup("winsep_refresh_on_resize"),
  callback = function()
    fixed_winsep.scheduler:schedule()
    float_winsep.scheduler:schedule()
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
  group = eve.nvim.augroup("float_winsep_refresh_on_win_enter"),
  callback = function()
    float_winsep.scheduler:schedule()
  end,
})

eve.state.observe({ eve.state.flight.dressing_winsep_fixed }, function()
  local enabled = eve.state.flight.dressing_winsep_float:snapshot() ---@type boolean
  if enabled then
    fixed_winsep.scheduler:schedule()
  else
    fixed_winsep.winsep:hide()
  end
end, false)

eve.state.observe({ eve.state.editor.winnr_fixed }, function()
  fixed_winsep.scheduler:schedule()
end, false)

eve.state.observe({ eve.state.flight.dressing_winsep_float }, function()
  float_winsep.scheduler:schedule()
end, false)
