---@diagnostic disable-next-line: unused-local
local __module_name__ = "ark.vendor.neovide.option" ---@type string

require("ark.vendor.neovim.option")

-- Cursor
vim.g.neovide_cursor_animation_length = 0
vim.g.neovide_cursor_vfx_mode = ""

-- Font inherits guifont from the common options.
vim.o.linespace = 0
vim.g.neovide_scale_factor = 1.0

-- Appearance
vim.g.neovide_floating_blur = false
-- Thin winsep floats also receive shadows, producing overlapping wedges.
vim.g.neovide_floating_shadow = false
vim.g.neovide_show_border = true
vim.g.neovide_opacity = 1
vim.g.neovide_theme = "bg_color"

-- Window
vim.g.neovide_fullscreen = true
vim.g.neovide_padding_top = 0
vim.g.neovide_padding_bottom = 0
vim.g.neovide_padding_right = 0
vim.g.neovide_padding_left = 0
vim.g.neovide_remember_window_size = true

-- Neovide owns smooth scrolling; keep the existing workspace toggle effective.
---@return nil
local function sync_scroll_animation()
  vim.g.neovide_scroll_animation_length = dot.context.flight.dressing_scroll:snapshot() and 0.3 or 0
end

sync_scroll_animation()
stl.fn.observe({ dot.context.flight.dressing_scroll }, sync_scroll_animation, true)

-- Initialize before TermOpen and refresh the palette used by new terminals.
---@return nil
local function sync_term_colors()
  local scheme = dot.context.theme.get_scheme(dot.context.theme.theme:snapshot()) ---@type stl.t.theme.IScheme|nil
  if scheme ~= nil then
    dot.context.theme.set_term_colors(scheme)
  end
end

sync_term_colors()
stl.fn.observe({ dot.context.theme.theme }, sync_term_colors, true)
