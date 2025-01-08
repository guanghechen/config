local wezterm = require("wezterm")
local act = wezterm.action

local config = {
	keys = {
		{ key = "Insert", mods = "CTRL", action = act.CopyTo("Clipboard") },
		{ key = "Insert", mods = "SHIFT", action = act.PasteFrom("Clipboard") },
		{ key = "v", mods = "ALT", action = act.PasteFrom("Clipboard") },
		{ key = "F", mods = "ALT|CTRL|SHIFT", action = act.ToggleFullScreen },
		{ key = "N", mods = "ALT|CTRL|SHIFT", action = act.SpawnCommandInNewWindow({ args = { "wezterm" } }) },
		{ key = "T", mods = "ALT|CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "W", mods = "ALT|CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
		{ key = "Z", mods = "ALT|CTRL|SHIFT", action = act.ToggleFullScreen },
		{ key = "0", mods = "ALT|CTRL|SHIFT", action = act.ResetFontSize },
		{ key = "=", mods = "ALT|CTRL|SHIFT", action = act.IncreaseFontSize },
		{ key = "-", mods = "ALT|CTRL|SHIFT", action = act.DecreaseFontSize },

		---

		{
			key = "[",
			mods = "ALT",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "[" }),
			}),
		},
	},
}

return config
