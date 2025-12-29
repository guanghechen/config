local c = require("dot.module.nvimbar").component
local Nvimbar = require("dot.module.nvimbar").Nvimbar

local dirtier = dot.state.status.dirtier_statusline ---@type ark.c.Dirtier
local position = "f_sl" ---@type ark.e.NvimbarPositionEnum

local statusline ---@type dot.module.nvimbar.Nvimbar
statusline = Nvimbar.new({
  name = "statusline",
  comp_sep = "  ",
  comp_sep_hlname = position .. "_bg",
  comp_sep_hlname_active = position .. "_bg",
  delay = 256,
  silent = function()
    local devmode = dot.context.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = stl.fn.falsy,
  on_fulfilled = function()
    local result = statusline:snapshot() or "" ---@type string
    vim.o.statusline = result
    dirtier:mark_clean()
  end,
})

statusline
  :place("left", c.host.username(position), 100)
  :place("left", c.nvim.mode(position), 100)
  :place("left", c.git.branch(position), 100)
  :place("left", c.file.readonly(position), 95)
  :place("left", c.file.format(position), 95)
  :place("left", c.file.indent(position), 95)
  :place("left", c.file.encoding(position), 100)
  :place("left", c.file.type(position))
  :place("left", c.file.size(position))
  :place("left", c.file.status(position))
  --
  :place("center", c.devmode.render_count(position), 100)
  --
  :place("right", c.nvim.pos(position), 100)
  :place("right", c.nvim.nr(position), 100)
  :place("right", c.nvim.pid(position), 100)
  :place("right", c.python.env(position), 100)
  :place("right", c.lsp.client(position), 100)
  :place("right", c.lint.status(position), 95)
  :place("right", c.ai.status(position), 95)
  :place("right", c.copilot.status(position), 95)
  :place("right", c.lsp.diagnostics(position), 95)
  :place("right", c.nvim.msg_mode(position), 95)
  :place("right", c.nvim.msg_command(position), 80)
  :place("right", c.nvim.msg_changes(position), 85)
  :place("right", c.nvim.msg_lsp(position), 90)

dirtier:subscribe(ark.c.Subscriber.new({
  on_next = function()
    if dirtier:is_dirty() then
      statusline:render()
    end
  end,
}))

vim.api.nvim_create_autocmd("ModeChanged", {
  group = ark.vim.fn.augroup("statusline_on_ModeChanged"),
  callback = function(evt)
    local m = evt.match ---@type string
    if string.sub(m, 1, 2) == "c:" or string.sub(m, #m - 1, #m) == ":c" then
      vim.schedule(function()
        local result = statusline:render(true) ---@type string
        vim.o.statusline = result
        vim.cmd("redraw")
      end)
    end
    statusline:render()
  end,
})

return statusline
