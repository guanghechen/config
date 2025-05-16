local os_name = vim.uv.os_uname().sysname ---@type string|nil

---@class std.env
local M = {}

---! OS settings
M.IS_MAC = os_name == "Darwin" ---@type boolean
M.IS_WIN = os_name == "Windows_NT" ---@type boolean
M.IS_WSL = vim.fn.has("wsl") == 1 ---@type boolean
M.IS_NIX = not M.IS_WSL and os_name == "Linux" ---@type boolean
M.IS_TMUX = vim.env.TMUX ~= nil ---@type boolean

M.IS_X64 = jit.arch == "x64" ---@type boolean
M.IS_X86 = jit.arch == "x86" ---@type boolean

M.PATH_ENV_SEP = M.IS_WIN and ";" or ":" ---@type string
M.PATH_SEP = M.IS_WIN and "\\" or "/" ---@type string
M.USERNAME = os.getenv("USER") or os.getenv("USERNAME") or "unknown" ---@type string

---! Path settings

M.HOME_USER = vim.env.HOME --[[@as string]]
M.HOME_NVIM_CACHE = vim.fn.stdpath("cache") --[[@as string]]
M.HOME_NVIM_CONFIG = vim.fn.stdpath("config") --[[@as string]]
M.HOME_NVIM_DATA = vim.fn.stdpath("data") --[[@as string]]
M.HOME_NVIM_STATE = vim.fn.stdpath("state") --[[@as string]]
M.HOME_CONTEXT = M.HOME_NVIM_STATE .. M.PATH_SEP .. "guanghechen" ---@type string

return M
