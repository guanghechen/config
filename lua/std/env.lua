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
  if vim.uv.fs_stat(dirpath .. PATH_SEP .. ".git") ~= nil then
    return dirpath
  end

  local pieces = rstd.path.split(dirpath, false) ---@type string[]
  for index = #pieces - 1, 1, -1 do
    local p = table.concat(pieces, PATH_SEP, 1, index) ---@type string
    if vim.uv.fs_stat(p .. PATH_SEP .. ".git") ~= nil then
      return p
    end
  end

  local ok, p = pcall(vim.fn.system, { "git", "-C", dirpath, "rev-parse", "--show-toplevel" }) ---@type boolean, string
  if not ok then
    return nil
  end

  if p:sub(1, 5) ~= "fatal" then
    return vim.trim(p)
  end

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

return M
