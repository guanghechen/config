local os_name = vim.uv.os_uname().sysname ---@type string|nil
local is_nix = os_name == "Linux" ---@type boolean
local is_mac = os_name == "Darwin" ---@type boolean
local is_win = os_name == "Windows_NT" ---@type boolean
local is_wsl = vim.fn.has("wsl") == 1 ---@type boolean
local PATH_SEP = is_win and "\\" or "/" ---@type string

---@class fml.std.os
local M = {}

---@return boolean
function M.is_mac()
  return is_mac
end

---@return boolean
function M.is_nix()
  return is_nix
end

---@return boolean
function M.is_win()
  return is_win
end

---@return boolean
function M.is_wsl()
  return is_wsl
end

---@return string
function M.path_sep()
  return PATH_SEP
end

return M
