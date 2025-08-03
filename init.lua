require("git"):setup()
require("full-border"):setup({
	type = ui.Border.ROUNDED,
})
require("starship"):setup({
	hide_flags = false,
	flags_after_prompt = true,
	config_file = "~/.config/yazi/starship.toml",
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
