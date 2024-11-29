local os_name = vim.uv.os_uname().sysname ---@type string|nil

---@class eve.builtin.constant
local M = {}

M.IS_NIX = os_name == "Linux" ---@type boolean
M.IS_MAC = os_name == "Darwin" ---@type boolean
M.IS_WIN = os_name == "Windows_NT" ---@type boolean
M.IS_WSL = vim.fn.has("wsl") == 1 ---@type boolean

M.PATH_SEP = M.IS_WIN and "\\" or "/" ---@type string

return M
