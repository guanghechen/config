local c = require("fml.dressing.nvimbar.components")

local dirtier = eve.status.dirtier_statusline ---@type eve.std.collection.IDirtier
local position = "f_sl" ---@type eve.ux.nvimbar.Position

local statusline ---@type eve.ux.INvimbar
statusline = eve.ux.Nvimbar.new({
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
  is_active = eve.std.fn.falsy,
  trigger_rerender = function()
    local result = statusline:snapshot() or "" ---@type string
    vim.o.statusline = result
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
  :place("right", c.fileindent(position), 95)
  :place("right", c.encoding(position), 100)
  :place("right", c.filetype(position), 95)
  :place("right", c.python_env(position), 100)
  :place("right", c.lsp(position), 100)
  :place("right", c.ai(position), 95)
  -- :place("right", c.copilot(position), 95)
  :place("right", c.diagnostics(position), 95)
  :place("right", c.msg_mode(position), 95)
  :place("right", c.msg_command(position), 80)
  :place("right", c.msg_changes(position), 85)
  :place("right", c.msg_lsp(position), 90)

dirtier:subscribe(eve.std.Subscriber.new({
  on_next = function()
    if dirtier:is_dirty() then
      statusline:render()
    end
  end,
}))

vim.api.nvim_create_autocmd("ModeChanged", {
  group = eve.nvim.augroup("statusline_on_ModeChanged"),
  callback = function(evt)
    local m = evt.match ---@type string
    if m:sub(1, 2) == "c:" or m:sub(#m - 1, #m) == ":c" then
      local result = statusline:render_immediately()
      vim.o.statusline = result
      vim.api.nvim__redraw({ flush = true })
    end
    statusline:render()
  end,
})

return statusline
