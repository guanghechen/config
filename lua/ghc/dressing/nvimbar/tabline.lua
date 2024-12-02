local functional = require("eve.lib.functional")
local Nvimbar = require("eve.lib.ux.nvimbar")
local Subscriber = require("eve.lib.collection.subscriber")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean
local dirtier = state.state.status.tabline_dirtier ---@type eve.lib.collection.IDirtier

local tabline ---@type eve.lib.ux.INvimbar
tabline = Nvimbar.new({
  name = "tabline",
  component_sep = "",
  component_sep_hlname = "f_sl_bg",
  component_sep_hlname_active = "f_sl_bg",
  render_delay = 128,
  silent = not devmode,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = functional.falsy,
  trigger_rerender = function()
    local result = tabline and tabline:snapshot() or "" ---@type string
    vim.opt.tabline = result
    dirtier:mark_clean()
  end,
  validate = function()
    return nil
  end,
})

tabline
  ---
  :register(c.devmode(), "right")
  :register(c.cwd(), "right")
  :register(c.tabs(), "right")
  --
  :register(c.debug_render_count(), "center")
  --
  :register(c.neotree(), "left")
  :register(c.diffview(), "left")
  :register(c.bufs(), "left")

dirtier:subscribe(Subscriber.new({
  on_next = function()
    if dirtier:is_dirty() then
      tabline:render()
    end
  end,
}))
