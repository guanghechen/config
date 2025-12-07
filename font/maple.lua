local wezterm = require("wezterm")

local family = "Maple Mono NF CN"

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
	font_size = 15,
	font = wezterm.font({
		family = family,
		weight = "Medium",
		harfbuzz_features = harfbuzz_features,
	}),
	font_rules = {
		{
			intensity = "Normal",
			italic = true,
			font = wezterm.font({
				family = family,
				weight = "Medium",
				style = "Italic",
				harfbuzz_features = harfbuzz_features,
			}),
		},
		{
			intensity = "Bold",
			italic = false,
			font = wezterm.font({
				family = family,
				weight = "Bold",
				harfbuzz_features = harfbuzz_features,
			}),
		},
		{
			intensity = "Bold",
			italic = true,
			font = wezterm.font({
				family = family,
				weight = "Bold",
				style = "Italic",
				harfbuzz_features = harfbuzz_features,
			}),
		},
		{
			intensity = "Half",
			italic = false,
			font = wezterm.font({
				family = family,
				weight = "Light",
				harfbuzz_features = harfbuzz_features,
			}),
		},
		{
			intensity = "Half",
			italic = true,
			font = wezterm.font({
				family = family,
				weight = "Light",
				style = "Italic",
				harfbuzz_features = harfbuzz_features,
			}),
		},
	},
}

return config
