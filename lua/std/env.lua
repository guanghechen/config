local os_name = vim.uv.os_uname().sysname ---@type string|nil

local IS_MAC = os_name == "Darwin" ---@type boolean
local IS_WIN = os_name == "Windows_NT" ---@type boolean
local IS_WSL = vim.fn.has("wsl") == 1 ---@type boolean
local IS_NIX = not IS_WSL and os_name == "Linux" ---@type boolean
local IS_TMUX = vim.env.TMUX ~= nil ---@type boolean

local IS_X64 = jit.arch == "x64" ---@type boolean
local IS_X86 = jit.arch == "x86" ---@type boolean

local PATH_ENV_SEP = IS_WIN and ";" or ":" ---@type string
local PATH_SEP = IS_WIN and "\\" or "/" ---@type string
local USERNAME = os.getenv("USER") or os.getenv("USERNAME") or "unknown" ---@type string

---@class std.env
local M = {}

---@param dirpath                       string
---@return string|nil
function M.locate_gitroot(dirpath)
  local dot_git_path = rstd.path.locate_nearest(dirpath, { ".git" }) ---@type string|nil
  if dot_git_path ~= nil then
    return rstd.path.dirname(dot_git_path, false, PATH_SEP)
  end

  local ok, p = pcall(vim.fn.system, { "git", "-C", dirpath, "rev-parse", "--show-toplevel" }) ---@type boolean, string
  if not ok then
    return nil
  end

  if p:sub(1, 5) ~= "fatal" then
    return vim.trim(p)
  end

  vim.notify("Git root located failed: " .. p, vim.log.levels.WARN)
  return nil
end

---! OS settings
M.IS_MAC = IS_MAC ---@type boolean
M.IS_WIN = IS_WIN ---@type boolean
M.IS_WSL = IS_WSL ---@type boolean
M.IS_NIX = IS_NIX ---@type boolean
M.IS_TMUX = IS_TMUX ---@type boolean

M.IS_X64 = IS_X64 ---@type boolean
M.IS_X86 = IS_X86 ---@type boolean

M.PATH_ENV_SEP = PATH_ENV_SEP ---@type string
M.PATH_SEP = PATH_SEP ---@type string
M.USERNAME = USERNAME ---@type string

M.HOME_USER = vim.env.HOME --[[@as string]]
M.HOME_CONFIG = vim.env.XDG_CONFIG_HOME or (M.HOME_USER .. PATH_SEP .. ".config") --[[@as string]]
M.HOME_NVIM_CACHE = vim.fn.stdpath("cache") --[[@as string]]
M.HOME_NVIM_CONFIG = vim.fn.stdpath("config") --[[@as string]]
M.HOME_NVIM_DATA = vim.fn.stdpath("data") --[[@as string]]
M.HOME_NVIM_STATE = vim.fn.stdpath("state") --[[@as string]]
M.HOME_CONTEXT = M.HOME_NVIM_STATE .. PATH_SEP .. "guanghechen" ---@type string
M.HOME_SHARED = M.HOME_USER .. PATH_SEP .. ".guanghechen" ---@type string

M.HOME_MASON = vim.env.MASON or (M.HOME_NVIM_DATA .. PATH_SEP .. "mason") ---@type string
M.HOME_MASON_BIN = M.HOME_MASON .. PATH_SEP .. "bin" ---@type string
if not vim.g.vscode and vim.uv.fs_stat(M.HOME_MASON_BIN) then
  vim.env.PATH = M.HOME_MASON_BIN .. PATH_ENV_SEP .. vim.env.PATH
end

return M
