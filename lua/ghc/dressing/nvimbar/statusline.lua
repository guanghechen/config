local functional = require("eve.lib.functional")
local Nvimbar = require("eve.lib.ux.nvimbar")
local Subscriber = require("eve.lib.collection.subscriber")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean
local dirtier = state.state.status.statusline_dirtier ---@type eve.lib.collection.IDirtier

local statusline ---@type eve.lib.ux.INvimbar
statusline = Nvimbar.new({
  name = "statusline",
  component_sep = "  ",
  component_sep_hlname = "f_sl_bg",
  component_sep_hlname_active = "f_sl_bg",
  render_delay = 128,
  silent = not devmode,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = functional.falsy,
  trigger_rerender = function()
    local result = statusline and statusline:snapshot() or "" ---@type string
    vim.opt.statusline = result
    dirtier:mark_clean()
  end,
  validate = function()
    return nil
  end,
})

statusline
  :register(c.username(), "left")
  :register(c.mode(), "left")
  :register(c.git(), "left")
  :register(c.filename(), "left")
  :register(c.filestatus(), "left")
  :register(c.readonly(), "left")
  --
  :register(c.debug_render_count(), "center")
  :register(c.widget(), "center")
  --
  :register(c.pos(), "right")
  :register(c.filesize(), "right")
  :register(c.filetype(), "right")
  :register(c.fileformat(), "right")
  :register(c.lsp(), "right")
  :register(c.copilot(), "right")
  :register(c.noice(), "right")
  :register(c.diagnostics(), "right")

dirtier:subscribe(Subscriber.new({
  on_next = function()
    if dirtier:is_dirty() then
      statusline:render()
    end
  end,
}))
