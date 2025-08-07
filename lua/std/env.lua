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

local BYTE_COLON = string.byte(":") ---@type integer
local BYTE_PATHSEP = string.byte(PATH_SEP) ---@type integer

---@class std.env
local M = {}

---@param dirpath                       string
---@return string|nil
function M.locate_gitroot(dirpath)
  if vim.uv.fs_stat(dirpath .. PATH_SEP .. ".git") ~= nil then
    return dirpath
  end

  local pieces = M.split_path(dirpath) ---@type string[]
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

---@param filepath                      string
---@return string
function M.normalize_path(filepath)
  if filepath == "/" and not IS_WIN then
    return "/"
  end

  if filepath == "" then
    return "."
  end

  filepath = filepath:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)

  local pieces = M.split_path(filepath, true)
  return table.concat(pieces, PATH_SEP)
end

---@param filepath                      string
---@param keep_suffix_sep               ?boolean
---@return string[]
---@return boolean
function M.split_path(filepath, keep_suffix_sep)
  local L = #filepath ---@type integer
  local pieces = {} ---@type string[]
  local pattern = "([^/\\]+)" ---@type string
  local has_prefix_sep = PATH_SEP == "/" and string.byte(filepath, 1, 1) == BYTE_PATHSEP ---@type boolean
  local has_suffix_sep = L > 1 and string.byte(filepath, L, L) == BYTE_PATHSEP ---@type boolean

  local k = 0 ---@type integer
  if has_prefix_sep then
    k = k + 1 ---@type integer
    pieces[k] = ""
  end

  for piece in string.gmatch(filepath, pattern) do
    if piece ~= "" and piece ~= "." then
      if piece == ".." and (has_prefix_sep or k > 0) then
        pieces[k] = nil
        k = k - 1 ---@type integer
      else
        k = k + 1 ---@type integer
        pieces[k] = piece
      end
    end
  end

  if has_suffix_sep and keep_suffix_sep then
    k = k + 1 ---@type integer
    pieces[k] = ""
  end

  if IS_WIN and L > 1 and string.byte(filepath, 2, 2) == BYTE_COLON then
    pieces[1] = pieces[1]:upper()
  end
  return pieces, has_suffix_sep
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
M.HOME_NVIM_CACHE = vim.fn.stdpath("cache") --[[@as string]]
M.HOME_NVIM_CONFIG = vim.fn.stdpath("config") --[[@as string]]
M.HOME_NVIM_DATA = vim.fn.stdpath("data") --[[@as string]]
M.HOME_NVIM_STATE = vim.fn.stdpath("state") --[[@as string]]
M.HOME_CONTEXT = M.HOME_NVIM_STATE .. PATH_SEP .. "guanghechen" ---@type string

return M
