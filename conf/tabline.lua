local wezterm = require("wezterm")

---@class tabline
local M = {}

-- Active tab icons (matching Kitty's active_tab_title_template)
local ACTIVE_LEFT_ICON = "󱝁 "
local ACTIVE_RIGHT_ICON = "󱝁 "

---@param tab_info table
---@return string
local function tab_title(tab_info)
	local title = tab_info.tab_title
	if title and #title > 0 then
		return title
	end
	return tab_info.active_pane.title
end

---@param config table
function M.setup(config)
	---@diagnostic disable-next-line: unused-local
	wezterm.on("format-tab-title", function(tab, tabs, _, _, hover, max_width)
		local theme = config.colors or {}
		local tab_bar = theme.tab_bar or {}

		local edge_bg = tab_bar.background or "#202020"
		local active = tab_bar.active_tab or {}
		local inactive = tab_bar.inactive_tab or {}
		local inactive_hover = tab_bar.inactive_tab_hover or inactive

		local bg, fg
		if tab.is_active then
			bg = active.bg_color or "#C586C0"
			fg = active.fg_color or "#202020"
		elseif hover then
			bg = inactive_hover.bg_color or "#3C3C3C"
			fg = inactive_hover.fg_color or "#FFFFFF"
		else
			bg = inactive.bg_color or "#202020"
			fg = inactive.fg_color or "#FFFFFF"
		end

		local title = tab_title(tab)
		local index = tab.tab_index + 1
		local is_first = index == 1 ---@type boolean

		-- Format title (active tab has icons only, no index)
		local formatted_title
		if tab.is_active then
			if is_first then
				formatted_title = string.format(" %s%s%s ", ACTIVE_LEFT_ICON, title, ACTIVE_RIGHT_ICON)
			else
				formatted_title = string.format(" %s%s%s", ACTIVE_LEFT_ICON, title, ACTIVE_RIGHT_ICON)
			end
		else
			if is_first then
				formatted_title = string.format(" %s | %d", title, index)
			else
				formatted_title = string.format("%s | %d", title, index)
			end
		end

		local elements = {}

		-- Left edge: no arrow for first tab
		if is_first then
			table.insert(elements, { Background = { Color = bg } })
		else
			table.insert(elements, { Background = { Color = edge_bg } })
			table.insert(elements, { Foreground = { Color = bg } })
			table.insert(elements, { Text = "" })
		end

		-- Tab content
		table.insert(elements, { Background = { Color = bg } })
		table.insert(elements, { Foreground = { Color = fg } })
		table.insert(elements, { Text = formatted_title })

		-- Right edge
		table.insert(elements, { Background = { Color = edge_bg } })
		table.insert(elements, { Foreground = { Color = bg } })
		table.insert(elements, { Text = "" })
		return elements
	end)
end

return M
