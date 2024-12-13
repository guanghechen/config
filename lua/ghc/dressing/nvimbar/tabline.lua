local functional = require("eve.lib.functional")
local Nvimbar = require("eve.lib.ux.nvimbar")
local Subscriber = require("eve.lib.collection.subscriber")
local status = require("eve.builtin.status")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean
local dirtier = status.tabline_dirtier ---@type eve.lib.collection.IDirtier
local position = "f_tl" ---@type eve.lib.ux.nvimbar.Position

local tabline ---@type eve.lib.ux.INvimbar
tabline = Nvimbar.new({
  name = "tabline",
  component_sep = "",
  component_sep_hlname = position .. "_bg",
  component_sep_hlname_active = position .. "_bg",
  render_delay = 256,
  silent = not devmode,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = functional.falsy,
  trigger_rerender = function()
    vim.opt.tabline = tabline:snapshot()
  end,
})

tabline
  ---
  :register(c.devmode(position), "right")
  -- :register(c.cwd(position), "right")
  :register(c.tabs(position), "right")
  --
  :register(c.debug_render_count(position), "center")
  --
  :register(c.neotree(position), "left")
  :register(c.diffview(position), "left")
  :register(c.bufs(position), "left")

dirtier:subscribe(Subscriber.new({
  on_next = function()
    tabline:render()
  end,
}))
