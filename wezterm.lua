local wezterm = require("wezterm")
local util = require("ghc.util")

local os_name = util.os_name() ---@type "nix"|"osx"|"win"
local platform_config = require("ghc.platform." .. os_name)

local harfbuzz_features = {
	"cv61=1",
	"cv62=1",
	"cv66=1",
	"cv98=1",
	"ss03=1",
	"ss07=1",
	"ss09=1",
	"ss10=1",
	"calt=1",
}

local config = {
	font_size = platform_config.font_size or 15.0,
	font = wezterm.font({
		family = "Maple Mono NF CN",
		weight = "Medium",
		harfbuzz_features = harfbuzz_features,
	}),
	font_rules = {
		-- Italic text
		{
			intensity = "Normal",
			italic = true,
			font = wezterm.font({
				family = "Maple Mono NF CN",
				weight = "Medium",
				style = "Italic",
				harfbuzz_features = harfbuzz_features,
			}),
		},
		-- Bold text
		{
			intensity = "Bold",
			italic = false,
			font = wezterm.font({
				family = "Maple Mono NF CN",
				weight = "ExtraBold",
				harfbuzz_features = harfbuzz_features,
			}),
		},
		-- Bold and Italic text
		{
			intensity = "Bold",
			italic = true,
			font = wezterm.font({
				family = "Maple Mono NF CN",
				weight = "ExtraBold",
				style = "Italic",
				harfbuzz_features = harfbuzz_features,
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
