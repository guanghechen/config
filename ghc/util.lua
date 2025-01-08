local wezterm = require("wezterm")

---@class ghc.util
local M = {}

---@return "nix"|"osx"|"win"
function M.os_name()
	local target = wezterm.target_triple

	if target:find("linux") then
		return "nix"
	elseif target:find("windows") then
		return "win"
	elseif target:find("darwin") then
		return "osx"
	end

	return "nix"
end

---@return table
function M.load_theme()
	local ok, theme = pcall(require, "local.theme")
	return ok and theme or require("theme.gruvbox_dark")
end

return M
