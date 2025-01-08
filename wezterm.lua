local wezterm = require("wezterm")
local util = require("ghc.util")

local os_name = util.os_name() ---@type "nix"|"osx"|"win"
local platform_config = require("ghc.platform." .. os_name)

local config = {
	font_size = 15.0,
	font = wezterm.font_with_fallback({ "Maple Mono Normal NL NF CN" }),
	disable_default_key_bindings = true,
	keys = platform_config.keys,
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

return config
