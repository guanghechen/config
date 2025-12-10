local __module_name__ = "dot.env"

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

local TERM = (os.getenv("TERM") or ""):lower() ---@type string
local TERM_PROGRAM = (os.getenv("TERM_PROGRAM") or ""):lower() ---@type string

local IS_KITTY = os.getenv("KITTY_PID") ~= nil or TERM:find("kitty", 1, true) ~= nil or TERM_PROGRAM == "kitty"
local IS_WEZTERM = os.getenv("WEZTERM_EXECUTABLE") ~= nil or TERM_PROGRAM == "wezterm"
local IS_GHOSTTY = os.getenv("GHOSTTY_RESOURCES_DIR") ~= nil or TERM_PROGRAM == "ghostty"

---@class dot.env
local M = {}

---@param dirpath                       string
---@return string|nil
function M.locate_gitroot(dirpath)
  local dot_git_path = yoz.path.locate_nearest(dirpath, { ".git" }) ---@type string|nil
  if dot_git_path ~= nil then
    return yoz.path.dirname(dot_git_path, false, PATH_SEP)
  end

  local ok, output = pcall(vim.fn.system, { "git", "-C", dirpath, "rev-parse", "--show-toplevel" }) ---@type boolean, string
  local trimmed_output = vim.trim(output or "")
  local shell_error = vim.v.shell_error ---@type integer

  if ok and shell_error == 0 and trimmed_output ~= "" and yoz.path.is_exist_dirpath(trimmed_output) then
    return trimmed_output
  end

  local message = "Failed to locate git root"
  local detail_payload = {
    dirpath = dirpath,
    output = trimmed_output,
    shell_error = shell_error,
    error = ok and nil or output,
  }
  local ok_json, detail_json = pcall(vim.json.encode, detail_payload)
  local details_text = ok_json and detail_json or vim.inspect(detail_payload, { newline = "\n", indent = "  " })
  local text = string.format("%s\n\n```json\n%s\n```", message, details_text)

  vim.notify(text, vim.log.levels.WARN, {
    title = string.format("%s │ locate_gitroot", __module_name__),
    group = string.format("%s:locate_gitroot", __module_name__),
    timeout = 3000,
    message = text,
    anonymous = false,
    silent = true,
  })
  return nil
end

---@param filepath                      string
---@param is_dir                        boolean
---@return nil
function M.mkdirs(filepath, is_dir)
  if is_dir then
    vim.fn.mkdir(filepath, "p")
  else
    vim.fn.mkdir(yoz.path.dirname(filepath, false, PATH_SEP), "p")
  end
end

---! OS settings
M.IS_MAC = IS_MAC ---@type boolean
M.IS_WIN = IS_WIN ---@type boolean
M.IS_WSL = IS_WSL ---@type boolean
M.IS_NIX = IS_NIX ---@type boolean
M.IS_TMUX = IS_TMUX ---@type boolean

M.IS_X64 = IS_X64 ---@type boolean
M.IS_X86 = IS_X86 ---@type boolean

---! Terminal settings
M.TERM = TERM ---@type string
M.TERM_PROGRAM = TERM_PROGRAM ---@type string
M.IS_KITTY = IS_KITTY ---@type boolean
M.IS_WEZTERM = IS_WEZTERM ---@type boolean
M.IS_GHOSTTY = IS_GHOSTTY ---@type boolean

M.PATH_ENV_SEP = PATH_ENV_SEP ---@type string
M.PATH_SEP = PATH_SEP ---@type string
M.USERNAME = USERNAME ---@type string

M.HOME_USER = vim.env.HOME --[[@as string]]
M.HOME_CONFIG = vim.env.XDG_CONFIG_HOME or (M.HOME_USER .. PATH_SEP .. ".config") --[[@as string]]
M.HOME_CONFIG_SHARED = M.HOME_CONFIG .. PATH_SEP .. "guanghechen" ---@type string
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
