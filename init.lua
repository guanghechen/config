require("git"):setup()
require("full-border"):setup({
	type = ui.Border.ROUNDED,
})
require("starship"):setup({
	hide_flags = false,
	flags_after_prompt = true,
	config_file = "~/.config/starship/yazi.toml",
})

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
