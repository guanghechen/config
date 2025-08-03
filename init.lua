require("full-border"):setup({ type = ui.Border.ROUNDED })
require("starship"):setup({ config_file = "~/.config/yazi/starship.toml" })
require("git"):setup()

Header:children_add(function()
	if ya.target_family() ~= "unix" then
		return ""
	end
	return ui.Span(ya.user_name() .. "@" .. ya.host_name() .. ":"):fg("blue")
end, 500, Header.LEFT)

function Status:name()
	local h = self._current.hovered
	if not h then
		return ui.Line("")
	end

	local linked = ""
	if h.link_to ~= nil then
		linked = " -> " .. tostring(h.link_to)
	end

	-- Apply proper styling to the status line text
	return ui.Line({
		ui.Span(" " .. h.name):fg("black"),
		ui.Span(linked):fg("cyan"),
	})
end
