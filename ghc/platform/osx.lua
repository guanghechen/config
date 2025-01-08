local wezterm = require("wezterm")
local act = wezterm.action

local config = {
	keys = {},
}

---@type string[]
local fn_keys = {
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
local a_to_z = {
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

for _, key in ipairs(fn_keys) do
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

for i = 0, 9, 1 do
	local key = tostring(i)
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
		mods = "CMD",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key, mods = "CTRL" }),
		}),
	})
end

for _, key in ipairs(a_to_z) do
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
		key = key:upper(),
		mods = "CTRL|SHIFT",
		action = act.Multiple({
			act.SendKey({ key = "Escape" }),
			act.SendKey({ key = key, mods = "CTRL" }),
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
		key = key:upper(),
		mods = "CMD|SHIFT",
		action = act.Multiple({
			act.SendKey({ key = "a", mods = "CTRL" }),
			act.SendKey({ key = key:upper() }),
		}),
	})
end

return config
