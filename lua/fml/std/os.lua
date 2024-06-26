---@class fml.std.os
local M = {}

local os_name = vim.uv.os_uname().sysname

---@return boolean
function M.is_mac()
  return os_name == "Darwin"
end

---@return boolean
function M.is_linux()
  return os_name == "Linux"
end

---@return boolean
function M.is_windows()
  return os_name == "Windows_NT"
end

---@return boolean
function M.is_wsl()
  return vim.fn.has("wsl") == 1
end

---@return string
function M.get_path_sep()
  return M.is_windows() and "\\" or "/"
end

return M
