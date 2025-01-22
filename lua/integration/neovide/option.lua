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
vim.g.transparency = 0.8
vim.g.neovide_background_color = "#252525" .. string.format("%x", math.floor(255 * (vim.g.transparency or 0.8)))
vim.g.neovide_floating_blur = false
vim.g.neovide_floating_blur_amount_x = 2.0
vim.g.neovide_floating_blur_amount_y = 2.0
vim.g.neovide_floating_opacity = 1.0
vim.g.neovide_floating_shadow = true
vim.g.neovide_floating_z_height = 10
vim.g.neovide_light_angle_degrees = 45
vim.g.neovide_light_radius = 5
vim.g.neovide_show_border = true
vim.g.neovide_transparency = 0
vim.g.neovide_window_blurred = true

-- Window
vim.g.neovide_fullscreen = false
vim.g.neovide_padding_top = 0
vim.g.neovide_padding_bottom = 0
vim.g.neovide_padding_right = 0
vim.g.neovide_padding_left = 0
vim.g.neovide_remember_window_size = true
