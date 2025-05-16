local c = eve.ux.nvimbar.component

local dirtier = eve.status.dirtier_statusline ---@type std.collection.IDirtier
local position = "f_sl" ---@type eve.ux.nvimbar.PositionEnum

local statusline ---@type eve.ux.nvimbar.Nvimbar
statusline = eve.ux.nvimbar.Nvimbar.new({
  name = "statusline",
  comp_sep = "  ",
  comp_sep_hlname = position .. "_bg",
  comp_sep_hlname_active = position .. "_bg",
  delay = 256,
  silent = function()
    local devmode = eve.context.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = std.fn.falsy,
  on_fulfilled = function()
    local result = statusline:snapshot() or "" ---@type string
    vim.o.statusline = result
    dirtier:mark_clean()
  end,
})

statusline
  :place("left", c.host.username(position), 100)
  :place("left", c.nvim.mode(position), 100)
  :place("left", c.nvim.pos(position), 100)
  :place("left", c.git.branch(position), 100)
  :place("left", c.file.readonly(position), 95)
  :place("left", c.file.path(position))
  :place("left", c.file.size(position))
  :place("left", c.file.status(position))
  --
  :place("center", c.devmode.render_count(position), 100)
  :place("center", c.widget.flags(position), 100)
  --
  :place("right", c.cwd.cwd(position), 100)
  :place("right", c.file.format(position), 95)
  :place("right", c.file.indent(position), 95)
  :place("right", c.file.encoding(position), 100)
  :place("right", c.file.type(position), 95)
  :place("right", c.python.env(position), 100)
  :place("right", c.lsp.client(position), 100)
  :place("right", c.ai.provider(position), 95)
  :place("right", c.lsp.diagnostics(position), 95)
  :place("right", c.nvim.msg_mode(position), 95)
  :place("right", c.nvim.msg_command(position), 80)
  :place("right", c.nvim.msg_changes(position), 85)
  :place("right", c.nvim.msg_lsp(position), 90)

dirtier:subscribe(std.Subscriber.new({
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
      vim.schedule(function()
        local result = statusline:render(true) ---@type string
        vim.o.statusline = result
        vim.api.nvim__redraw({ statusline = true, flush = true })
      end)
    end
    statusline:render()
  end,
})

return statusline
