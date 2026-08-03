local wezterm = require("wezterm")

---@class env
local M = {}

local target = wezterm.target_triple

local is_wsl = false
if target:find("windows") then
  local success, code = pcall(wezterm.run_child_process, {
    "bash",
    "-c",
    "grep -qi microsoft /proc/version",
  })
  is_wsl = (success and code == 0)
end

M.IS_NIX = target:find("linux") ~= nil
M.IS_OSX = target:find("darwin") ~= nil
M.IS_WIN = target:find("windows") and not is_wsl
M.IS_WSL = is_wsl

return M
