local wezterm = require("wezterm")
local act = wezterm.action

local config = {
	keys = {
		{ key = "Insert", mods = "CTRL", action = act.CopyTo("Clipboard") },
		{ key = "Insert", mods = "SHIFT", action = act.PasteFrom("Clipboard") },
		{ key = "v", mods = "CMD", action = act.PasteFrom("Clipboard") },
		{ key = "F", mods = "CMD|CTRL|SHIFT", action = act.ToggleFullScreen },
		{ key = "N", mods = "CMD|CTRL|SHIFT", action = act.SpawnCommandInNewWindow({ args = { "wezterm" } }) },
		{ key = "T", mods = "CMD|CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "W", mods = "CMD|CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
		{ key = "Z", mods = "CMD|CTRL|SHIFT", action = act.ToggleFullScreen },
		{ key = "0", mods = "CMD|CTRL|SHIFT", action = act.ResetFontSize },
		{ key = "=", mods = "CMD|CTRL|SHIFT", action = act.IncreaseFontSize },
		{ key = "-", mods = "CMD|CTRL|SHIFT", action = act.DecreaseFontSize },

		---

		{
			key = "Enter",
			mods = "CMD",
			action = act.Multiple({
				act.SendKey({ key = "Escape" }),
				act.SendKey({ key = "Enter" }),
			}),
		},
		{
			key = "`",
			mods = "CMD",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "`" }),
			}),
		},
		{
			key = ",",
			mods = "CMD",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "," }),
			}),
		},
		{
			key = ".",
			mods = "CMD",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "." }),
			}),
		},
		{
			key = "[",
			mods = "CMD",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "[" }),
			}),
		},
		{
			key = "]",
			mods = "CMD",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "]" }),
			}),
		},
		{
			key = ":",
			mods = "CMD|SHIFT",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = ":", mods = "SHIFT" }),
			}),
		},
		{
			key = "<",
			mods = "CMD|SHIFT",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "<", mods = "SHIFT" }),
			}),
		},
		{
			key = ">",
			mods = "CMD|SHIFT",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = ">", mods = "SHIFT" }),
			}),
		},
		{
			key = "{",
			mods = "CMD|SHIFT",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "{", mods = "SHIFT" }),
			}),
		},
		{
			key = "}",
			mods = "CMD|SHIFT",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = "}", mods = "SHIFT" }),
			}),
		},
	},
}

---@type string[]
local fns = {
	"F1",
	"F2",
	"F3",
	"F4",
	"F5",
	"F6",
	"F7",
	"F8",
	"F9",
	"F10",
	"F11",
	"F12",
}

---@type string[]
local arrows = {
	"UpArrow",
	"RightArrow",
	"DownArrow",
	"LeftArrow",
}

---@type string[]
local digits = {
	"0",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
}

---@type string[]
local letters = {
	"a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
}

for _, key in ipairs(fns) do
	table.insert(config.keys, {
		key = key,
		mods = "CMD",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key }),
		}),
	})
end

for _, key in ipairs(arrows) do
	table.insert(config.keys, {
		key = key,
		mods = "CMD",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key }),
		}),
	})

	table.insert(config.keys, {
		key = key,
		mods = "CMD|CTRL",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key, mods = "CTRL" }),
		}),
	})

	table.insert(config.keys, {
		key = key,
		mods = "CMD|SHIFT",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key, mods = "SHIFT" }),
		}),
	})
end

for _, key in ipairs(digits) do
	table.insert(config.keys, {
		key = key,
		mods = "CMD",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key }),
		}),
	})
	table.insert(config.keys, {
		key = key,
		mods = "CMD|CTRL",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key, mods = "CTRL" }),
		}),
	})
end

for _, key in ipairs(letters) do
	if key ~= "v" then
		table.insert(config.keys, {
			key = key,
			mods = "CMD",
			action = act.Multiple({
				act.SendKey({ key = "a", mods = "CTRL" }),
				act.SendKey({ key = key }),
			}),
		})
	end

	table.insert(config.keys, {
		key = key,
		mods = "CMD|CTRL",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key, mods = "CTRL" }),
		}),
	})

	table.insert(config.keys, {
		key = key:upper(),
		mods = "CMD|SHIFT",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key:upper() }),
		}),
	})

	table.insert(config.keys, {
		key = key:upper(),
		mods = "CTRL|SHIFT",
		action = act.Multiple({
			act.SendKey({ key = "Escape" }),
			act.SendKey({ key = key:upper(), mods = "CTRL" }),
		}),
	})
end

return config
