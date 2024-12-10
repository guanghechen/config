local functional = require("eve.lib.functional")
local Nvimbar = require("eve.lib.ux.nvimbar")
local Subscriber = require("eve.lib.collection.subscriber")
local status = require("eve.builtin.status")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean
local dirtier = status.statusline_dirtier ---@type eve.lib.collection.IDirtier
local position = "f_sl" ---@type eve.lib.ux.nvimbar.Position

local statusline ---@type eve.lib.ux.INvimbar
statusline = Nvimbar.new({
  name = "statusline",
  component_sep = "  ",
  component_sep_hlname = position .. "_bg",
  component_sep_hlname_active = position .. "_bg",
  render_delay = 256,
  silent = not devmode,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = functional.falsy,
  trigger_rerender = function()
    local result = statusline:snapshot() or "" ---@type string
    vim.opt.statusline = result
    dirtier:mark_clean()
  end,
})

statusline
  :register(c.username(position), "left")
  :register(c.mode(position), "left")
  :register(c.git(position), "left")
  :register(c.readonly(position), "left")
  :register(c.filepath(position), "left")
  :register(c.filesize(position), "left")
  :register(c.filestatus(position), "left")
  --
  :register(c.debug_render_count(position), "center")
  :register(c.widget(position), "center")
  --
  :register(c.pos(position), "right")
  :register(c.fileformat(position), "right")
  :register(c.filetype(position), "right")
  :register(c.lsp_message(position), "right")
  :register(c.lsp(position), "right")
  :register(c.copilot(position), "right")
  :register(c.diagnostics(position), "right")
  :register(c.noice(position), "right")

dirtier:subscribe(Subscriber.new({
  on_next = function()
    if dirtier:is_dirty() then
      statusline:render()
    end
  end,
}))
