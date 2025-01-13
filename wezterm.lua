local wezterm = require("wezterm")
local util = require("ghc.util")

local os_name = util.os_name() ---@type "nix"|"osx"|"win"
local platform_config = require("ghc.platform." .. os_name)

local config = {
	font_size = platform_config.font_size or 15.0,
	font = wezterm.font({
		family = "Maple Mono Normal NL NF CN",
		weight = "Medium",
	}),
	font_rules = {
		-- Italic text
		{
			intensity = "Normal",
			italic = true,
			font = wezterm.font({
				family = "Maple Mono Normal NL NF CN",
				weight = "Medium",
				style = "Italic",
			}),
		},
		-- Bold text
		{
			intensity = "Bold",
			italic = false,
			font = wezterm.font({
				family = "Maple Mono Normal NL NF CN",
				weight = "ExtraBold",
			}),
		},
		-- Bold and Italic text
		{
			intensity = "Bold",
			italic = true,
			font = wezterm.font({
				family = "Maple Mono Normal NL NF CN",
				weight = "ExtraBold",
				style = "Italic",
			}),
		},
	},
	disable_default_key_bindings = true,
	initial_rows = 40,
	initial_cols = 120,
	keys = platform_config.keys,
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

local theme = util.load_theme() or {} ---@type table
for key, val in pairs(theme) do
	config[key] = val
end

return config
