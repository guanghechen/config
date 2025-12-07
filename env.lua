local wezterm = require("wezterm")

---@class env
local M = {}

local target = wezterm.target_triple

M.IS_NIX = target:find("linux") ~= nil
M.IS_MAC = target:find("darwin") ~= nil
M.IS_WIN = target:find("windows") ~= nil and os.getenv("WSL_DISTRO_NAME") == nil
M.IS_WSL = target:find("windows") ~= nil and os.getenv("WSL_DISTRO_NAME") ~= nil

---@type "nix"|"mac"|"win"|"wsl"
M.OSNAME = M.IS_MAC and "mac" or M.IS_WSL and "wsl" or M.IS_WIN and "win" or "nix"

return M
