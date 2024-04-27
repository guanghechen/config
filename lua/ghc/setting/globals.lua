local os_name = vim.loop.os_uname().sysname
local is_mac = os_name == "Darwin"
local is_linux = os_name == "Linux"
local is_windows = os_name == "Windows_NT"
local is_wsl = vim.fn.has("wsl") == 1
local config_path = vim.fn.stdpath("config")
local data_path = vim.fn.stdpath("data")
local path_sep = is_windows and "\\" or "/"
local home = is_windows and os.getenv("USERPROFILE") or os.getenv("HOME")

---@class ghc.setting.globals
local globals = {
  is_mac = is_mac,
  is_linux = is_linux,
  is_windows = is_windows,
  is_wsl = is_wsl,
  config_path = config_path,
  data_path = data_path,
  path_sep = path_sep,
  home = home,
}

return globals

