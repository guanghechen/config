local function get_starship_config()
	local sep = package.config:sub(1, 1)
	local home = os.getenv("HOME")
	if home then
		return home .. sep .. ".config" .. sep .. "yazi" .. sep .. "starship.toml"
	end
	local appdata = os.getenv("APPDATA")
	if appdata then
		return appdata .. sep .. "yazi" .. sep .. "config" .. sep .. "starship.toml"
	end
	return nil
end

require("git"):setup()
require("full-border"):setup({
	type = ui.Border.ROUNDED,
})
require("starship"):setup({
	hide_flags = false,
	flags_after_prompt = true,
	config_file = get_starship_config(),
})

Header:children_add(function()
	if ya.target_family() ~= "unix" then
		return ""
	end
	return ui.Span(ya.user_name() .. "@" .. ya.host_name() .. ":"):fg("blue")
end, 500, Header.LEFT)

function Status:name()
	local h = self._current.hovered
	if not h then
		return ""
	end

	local linked = ""
	if h.link_to ~= nil then
		linked = " -> " .. tostring(h.link_to)
	end
	return ui.Line(" " .. h.name .. linked)
end
