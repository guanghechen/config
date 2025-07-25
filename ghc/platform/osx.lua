local wezterm = require("wezterm")
local act = wezterm.action

local config = {
	font_size = 15.0,
	keys = {
		{ key = "Insert", mods = "CTRL", action = act.CopyTo("Clipboard") },
		{ key = "Insert", mods = "SHIFT", action = act.PasteFrom("Clipboard") },
		{ key = "F11", mods = "", action = act.ToggleFullScreen },
		{ key = "v", mods = "CMD", action = act.PasteFrom("Clipboard") },
		{ key = "N", mods = "CMD|CTRL|SHIFT", action = act.SpawnCommandInNewWindow({ args = { "wezterm" } }) },
		{ key = "T", mods = "CMD|CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
		{ key = "W", mods = "CMD|CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
		{ key = ")", mods = "CMD|CTRL|SHIFT", action = act.ResetFontSize },
		{ key = "+", mods = "CMD|CTRL|SHIFT", action = act.IncreaseFontSize },
		{ key = "_", mods = "CMD|CTRL|SHIFT", action = act.DecreaseFontSize },

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

	-- CSI u format for ctrl+shift+letter: \u001b[{ascii_code};6u
	local ascii_code = string.byte(key:upper())
	table.insert(config.keys, {
		key = key:upper(),
		mods = "CTRL|SHIFT",
		action = act.SendString(string.format("\x1b[%d;6u", ascii_code)),
	})
end

do
	-- CSI u format for ctrl keys (matching kitty bindings)
	local keys = {
		{ key = ",", code = 44 }, -- ctrl+comma
		{ key = ".", code = 46 }, -- ctrl+period
		{ key = "/", code = 47 }, -- ctrl+slash
		{ key = "0", code = 48 }, -- ctrl+0
		{ key = "1", code = 49 }, -- ctrl+1
		{ key = "2", code = 50 }, -- ctrl+2
		{ key = "3", code = 51 }, -- ctrl+3
		{ key = "4", code = 52 }, -- ctrl+4
		{ key = "5", code = 53 }, -- ctrl+5
		{ key = "6", code = 54 }, -- ctrl+6
		{ key = "7", code = 55 }, -- ctrl+7
		{ key = "8", code = 56 }, -- ctrl+8
		{ key = "9", code = 57 }, -- ctrl+9
		{ key = "[", code = 91 }, -- ctrl+left bracket
		{ key = "]", code = 93 }, -- ctrl+right bracket
		{ key = "`", code = 96 }, -- ctrl+backtick
	}

	for _, entry in ipairs(keys) do
		table.insert(config.keys, {
			key = entry.key,
			mods = "CTRL",
			action = act.SendString(string.format("\x1b[%d;5u", entry.code)),
		})
	end
end

do
	-- CSI u format for ctrl+shift+punctuation
	local keys = {
		{ key = "<", code = 44 }, -- comma
		{ key = ">", code = 46 }, -- period
		{ key = "?", code = 47 }, -- slash
		{ key = "{", code = 91 }, -- left bracket
		{ key = "}", code = 93 }, -- right bracket
	}

	for _, entry in ipairs(keys) do
		table.insert(config.keys, {
			key = entry.key,
			mods = "CTRL|SHIFT",
			action = act.SendString(string.format("\x1b[%d;6u", entry.code)),
		})
	end
end

return config
