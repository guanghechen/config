local env = require("env")

local keymap_config = require("keymap." .. env.OSNAME)
local font_config = require("font.maple")

local config = {
	disable_default_key_bindings = true,
	initial_rows = 40,
	initial_cols = 120,
	keys = keymap_config.keys,
	native_macos_fullscreen_mode = true,
	send_composed_key_when_left_alt_is_pressed = false,
	send_composed_key_when_right_alt_is_pressed = true,
	window_decorations = "RESIZE",
	window_padding = {
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	},
	enable_tab_bar = false,
	tab_bar_at_bottom = false,
	tab_max_width = 16,
}

for key, val in pairs(font_config) do
	config[key] = val
end

local theme = env.load_theme() or {} ---@type table
for key, val in pairs(theme) do
	config[key] = val
end

return config
