local SEP = dot.env.PATH_SEP ---@type string
local HOME_CONFIG = dot.env.HOME_CONFIG ---@type string
local HOME_CONFIG_SHARED = dot.env.HOME_CONFIG_SHARED ---@type string
local HOME_NVIM_CACHE = dot.env.HOME_NVIM_CACHE ---@type string
local HOME_NVIM_CONFIG = dot.env.HOME_NVIM_CONFIG ---@type string
local HOME_NVIM_DATA = dot.env.HOME_NVIM_DATA ---@type string
local HOME_CONTEXT = dot.env.HOME_CONTEXT ---@type string
local HOME_SHARED = dot.env.HOME_SHARED ---@type string

local CWD ---@type string
local WORKSPACE ---@type string
local IS_GIT_REPO ---@type boolean
do
  local cwd = vim.fn.getcwd() ---@type string
  local gitrepo = dot.env.locate_gitroot(cwd) ---@type string|nil
  CWD = cwd ---@type string
  WORKSPACE = gitrepo or cwd ---@type string
  IS_GIT_REPO = gitrepo ~= nil ---@type boolean
end

---@class std.path.reposcope_map
local repo_map = {
  public = {
    [".config"] = {
      "alacritty",
      "bat",
      "btop",
      "claude",
      "fd",
      "fish",
      "fzf",
      "git-delta",
      "ghostty",
      "guanghechen",
      "helix",
      "kitty",
      "lazygit",
      "lsd",
      "nvim",
      "nvim-lazy",
      "nvim-nvchad",
      "pm2",
      "pwsh",
      "ripgrep",
      "skhd",
      "tmux",
      "tsuki",
      "wezterm",
      "yabai",
      "yasb",
      "yazi",
      "yoz",
      "zellij",
    },
    ["guanghechen"] = {
      "algorithm.ts",
      "asset",
      "koa",
      "mirror",
      "node-scaffolds",
      "react-kit",
      "sora",
      "static-resources",
    },
    ["yozora"] = {
      "yozora",
      "yozora-react",
      "yozora-html",
      "gatsby-scaffolds",
    },
  },
}

---@module 'std.path'
---@class std.path
local M = {}

---@param filepath                      string
---@return string
function M.dirname(filepath)
  return yoz.path.dirname(filepath, false, SEP)
end

---@param filepath                      string
---@return boolean
function M.is_exist(filepath)
  return yoz.path.is_exist(filepath)
end

---@param filepath                      string
---@return boolean
function M.is_exist_filepath(filepath)
  return yoz.path.is_exist_file(filepath)
end

---@return boolean
function M.is_git_repo()
  return IS_GIT_REPO
end

---@param filepath                      string
---@return boolean
function M.is_git_ignored(filepath)
  vim.fn.system({ "git", "check-ignore", "-q", filepath })
  return vim.v.shell_error == 0
end

---@param from                          string
---@param to                            string
---@return string
function M.join(from, to)
  return yoz.path.join(from, to, true, SEP)
end

---@param filepath                      string
---@param keep_trailing_slash           ?boolean
---@param sep                           ?'/'|'\'
---@return string
function M.normalize(filepath, keep_trailing_slash, sep)
  return yoz.path.normalize(filepath, keep_trailing_slash ~= false, sep or SEP)
end

---@param from                          string
---@param to                            string
---@param sep                           ?'/'|'\'
---@return string
function M.relative(from, to, sep)
  return yoz.path.relative(from, to, false, sep or SEP)
end

---@param cwd                           string
---@param to                            string
function M.resolve(cwd, to)
  return yoz.path.resolve(cwd, to, true, SEP)
end

---@param path                          string
---@return string
function M.shorten(path)
  return vim.fn.pathshorten(path)
end

----------------------------------------------------------------------------------------------------

---@return boolean
function M.is_repo_personal_public()
  if not IS_GIT_REPO then
    return false
  end

  local workspace = M.workspace() ---@type string
  local pieces = yoz.path.split(workspace, false) ---@type string[]
  if #pieces <= 2 then
    return false
  end

  local reposcope = pieces[#pieces - 1] ---@type string
  local reponame = pieces[#pieces] ---@type string
  local reponames = repo_map.public[reposcope] ---@type string[]|nil
  return reponames ~= nil and vim.list_contains(reponames, reponame) or reposcope == "lazy" ---@type boolean
end

---@return boolean
function M.is_repo_playground()
  if not IS_GIT_REPO then
    return false
  end

  local workspace = M.workspace() ---@type string
  local pieces = yoz.path.split(workspace, false) ---@type string[]
  return vim.list_contains(pieces, "playground")
end

---@return boolean
function M.is_repo_thirdparty()
  if not IS_GIT_REPO then
    return false
  end

  local workspace = M.workspace() ---@type string
  local pieces = yoz.path.split(workspace, false) ---@type string[]
  return vim.list_contains(pieces, "sourcecode") or vim.list_contains(pieces, "sourcecodes")
end

---@return string
function M.workspace()
  return WORKSPACE ---@type string
end

---@return string
function M.cwd()
  return CWD ---@type string
end

----------------------------------------------------------------------------------------------------

---@param app                           string
---@return string
function M.locate_app_config_home(app)
  return M.join(HOME_CONFIG, app)
end

---@param filename                      string
---@return string
function M.locate_config_shared_filepath(filename)
  return M.join(HOME_CONFIG_SHARED, "_shared/config/" .. filename)
end

---@param filename                      string
---@return string
function M.locate_cache_filepath(filename)
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)

  local hash = yoz.fn.md5(workspace_path)

  local dirpath = M.join(HOME_NVIM_CACHE, "guanghechen" .. SEP .. workspace_name .. "@" .. hash) ---@type string
  local filepath = M.join(dirpath, filename) ---@type string
  dot.env.mkdirs(dirpath, true)
  return filepath
end

---@param filename                      string
---@return string
function M.locate_config_filepath(filename)
  return M.join(HOME_NVIM_CONFIG, filename)
end

---@param filename                      string
---@return string
function M.locate_context_filepath(filename)
  return M.join(HOME_CONTEXT, filename)
end

---@param filename                      string
---@return string
function M.locate_data_filepath(filename)
  return M.join(HOME_NVIM_DATA, filename)
end

---@param filename                      string
---@return string
function M.locate_log_filepath(filename)
  return M.locate_workspace_filepath("log/" .. filename)
end

---@param filename                      string
---@return string
function M.locate_script_filepath(filename)
  return M.join(HOME_NVIM_CONFIG, "script/" .. filename)
end

---@param filename                      string
---@return string
function M.locate_shared_filepath(filename)
  return M.join(HOME_SHARED, filename)
end

---@param filename                      string
---@return string
function M.locate_workspace_filepath(filename)
  local workspace_path = M.workspace() ---@type string
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path) ---@type string
  local hash = yoz.fn.md5(workspace_path) ---@type string
  local session_dir = workspace_name .. "@" .. hash ---@type string
  return M.locate_context_filepath("workspaces" .. SEP .. session_dir .. SEP .. filename)
end

return M
