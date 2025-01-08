local wezterm = require("wezterm")

local config = {
	keys = {
		{
			key = "a",
			mods = "CMD",
			action = wezterm.action.SendKey({ key = "a", mods = "CTRL" }),
		},
	},
}

return config
