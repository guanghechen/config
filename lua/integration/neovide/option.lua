require("integration.neovim.option")

-- Appearance
vim.g.neovide_padding_top = 0
vim.g.neovide_padding_bottom = 0
vim.g.neovide_padding_right = 0
vim.g.neovide_padding_left = 0

-- Cursor
vim.g.neovide_cursor_trail_size = 0
vim.g.neovide_cursor_trail_length = 0
vim.g.neovide_cursor_vfx_mode = "railgun"

-- Font
vim.o.guifont = "Maple Mono NF CN:h15"
vim.o.linespace = 0
vim.g.neovide_scale_factor = 1.0

-- Transparency
vim.g.transparency = 0.85
vim.g.neovide_floating_blur = false
vim.g.neovide_floating_blur_amount_x = 2.0
vim.g.neovide_floating_blur_amount_y = 2.0
vim.g.neovide_floating_opacity = 1.0
vim.g.neovide_floating_shadow = true
vim.g.neovide_floating_z_height = 10
vim.g.neovide_light_angle_degrees = 45
vim.g.neovide_light_radius = 5
vim.g.neovide_show_border = true
vim.g.neovide_transparency = 1
vim.g.neovide_window_blurred = true

-- Window
vim.g.neovide_fullscreen = true
vim.g.neovide_padding_top = 0
vim.g.neovide_padding_bottom = 0
vim.g.neovide_padding_right = 0
vim.g.neovide_padding_left = 0
vim.g.neovide_remember_window_size = true

do
  local scheme = eve.context.theme.get_scheme(eve.context.theme.theme:snapshot()) ---@type std.t.theme.IScheme | nil
  if scheme ~= nil then
    local c = scheme.palette.unified ---@type std.t.theme.UnifiedPalette
    vim.g.terminal_color_0 = c.bg0
    vim.g.terminal_color_1 = c.red
    vim.g.terminal_color_2 = c.green
    vim.g.terminal_color_3 = c.yellow
    vim.g.terminal_color_4 = c.blue
    vim.g.terminal_color_5 = c.purple
    vim.g.terminal_color_6 = c.aqua
    vim.g.terminal_color_7 = c.fg1
    vim.g.terminal_color_8 = c.bg0
    vim.g.terminal_color_9 = c.brightRed
    vim.g.terminal_color_10 = c.brightGreen
    vim.g.terminal_color_11 = c.brightYellow
    vim.g.terminal_color_12 = c.brightBlue
    vim.g.terminal_color_13 = c.brightPurple
    vim.g.terminal_color_14 = c.brightAqua
    vim.g.terminal_color_15 = c.fg1

    vim.g.neovide_theme = scheme.darken and "dark" or "light"
  end
end
