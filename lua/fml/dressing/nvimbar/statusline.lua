local Nvimbar = require("fml.ux.nvimbar")
local c = require("fml.dressing.nvimbar.components")

local dirtier = eve.state.status.dirtier_statusline ---@type eve.collection.IDirtier
local position = "f_sl" ---@type fml.ux.nvimbar.Position

local statusline ---@type fml.ux.INvimbar
statusline = Nvimbar.new({
  name = "statusline",
  comp_sep = "  ",
  comp_sep_hlname = position .. "_bg",
  comp_sep_hlname_active = position .. "_bg",
  render_delay = 256,
  silent = function()
    local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = eve.fn.falsy,
  trigger_rerender = function()
    local result = statusline:snapshot() or "" ---@type string
    vim.opt.statusline = result
    dirtier:mark_clean()
  end,
})

statusline
  :place("left", c.username(position), 100)
  :place("left", c.mode(position), 100)
  :place("left", c.pos(position), 100)
  :place("left", c.git(position), 100)
  :place("left", c.readonly(position), 95)
  :place("left", c.filepath(position))
  :place("left", c.filesize(position))
  :place("left", c.filestatus(position))
  --
  :place("center", c.debug_render_count(position), 100)
  :place("center", c.widget(position), 100)
  --
  :place("right", c.cwd(position), 100)
  :place("right", c.fileformat(position), 95)
  :place("right", c.python_env(position), 100)
  :place("right", c.filetype(position), 95)
  :place("right", c.lsp_message(position), 90)
  :place("right", c.lsp(position), 100)
  :place("right", c.ai(position), 95)
  -- :place("right", c.copilot(position), 95)
  :place("right", c.diagnostics(position), 95)
  :place("right", c.noice_mode(position), 95)

dirtier:subscribe(eve.col.Subscriber.new({
  on_next = function()
    if dirtier:is_dirty() then
      statusline:render()
    end
  end,
}))

return statusline
