local SEP = std.env.PATH_SEP ---@type string
local IS_WIN = std.env.IS_WIN ---@type boolean
local HOME_NVIM_CACHE = std.env.HOME_NVIM_CACHE ---@type string
local HOME_NVIM_CONFIG = std.env.HOME_NVIM_CONFIG ---@type string
local HOME_NVIM_DATA = std.env.HOME_NVIM_DATA ---@type string
local HOME_CONTEXT = std.env.HOME_CONTEXT ---@type string

-- stylua: ignore start
local BYTE_SLASH      = std.byte.BYTES.SLASH      ---@type integer '/'
local BYTE_BACKSLASH  = std.byte.BYTES.BACKSLASH  ---@type integer '\\'
local BYTE_COLON      = std.byte.BYTES.COLON      ---@type integer ':'
local BYTE_PATHSEP    = string.byte(SEP)          ---@type integer
-- stylua: ignore end

local CWD ---@type string
local WORKSPACE ---@type string
local IS_GIT_REPO ---@type boolean
do
  local cwd = vim.fn.getcwd() ---@type string
  local gitrepo = std.env.locate_gitroot(cwd) ---@type string|nil
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

---@class std.path
local M = {}

M.normalize = std.env.normalize_path
M.split = std.env.split_path

---@param filepath                      string
---@return string
function M.basename(filepath)
  if filepath == "" then
    return ""
  end

  local pos_invalid = #filepath + 1 ---@type integer
  local pos_sep = 0 ---@type integer

  for i = #filepath, 1, -1 do
    local byte = string.byte(filepath, i, i) ---@type integer
    if byte == BYTE_SLASH or byte == BYTE_BACKSLASH then
      if i + 1 == pos_invalid then
        pos_invalid = i
      else
        pos_sep = i
        break
      end
    end
  end

  if pos_sep == 0 and pos_invalid == #filepath + 1 then
    return filepath
  end
  return string.sub(filepath, pos_sep + 1, pos_invalid - 1)
end

---@param filepath                      string
---@return string
function M.dirname(filepath)
  local pieces = M.split(filepath)
  if #pieces == 1 then
    local piece = pieces[1] ---@type string
    return piece == "" and string.byte(filepath, 1, 1) == BYTE_SLASH and "/" or piece
  end
  local dirpath = #pieces > 0 and table.concat(pieces, SEP, 1, #pieces - 1) or "" ---@type string
  return dirpath == "" and string.byte(filepath, 1, 1) == BYTE_SLASH and "/" or dirpath
end

---@param filename                      string
---@return string
function M.extname(filename)
  return filename:match("%.[^.]+$") or ""
end

---@param filepath                      string
---@return boolean
function M.is_absolute(filepath)
  return string.byte(filepath, 1, 1) == BYTE_PATHSEP
end

if IS_WIN then
  ---@param filepath                      string
  ---@return boolean
  function M.is_absolute(filepath)
    return #filepath > 1 and string.byte(filepath, 2, 2) == BYTE_COLON
  end
end

---@param filepath                      string
---@return boolean
function M.is_dirpath(filepath)
  local N = #filepath ---@type integer
  if N < 1 then
    return true
  end

  local tc = filepath:sub(N, N) ---@type string
  return tc == "/" or tc == "\\"
end

---@param filepath                      string
---@return boolean
function M.is_exist(filepath)
  local stat = vim.uv.fs_stat(filepath)
  return stat ~= nil and not vim.tbl_isempty(stat)
end

---@param dirpath                       string
---@return boolean
function M.is_exist_dirpath(dirpath)
  local stat = vim.uv.fs_stat(dirpath)
  return stat ~= nil and stat.type == "directory"
end

---@param filepath                      string
---@return boolean
function M.is_exist_filepath(filepath)
  local stat = vim.uv.fs_stat(filepath)
  return stat ~= nil and stat.type == "file"
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

---! Check if the `to` path is under the `from` path.
---@param from                          string
---@param to                            string
---@return boolean
function M.is_under(from, to)
  local is_from_absolute = M.is_absolute(from) ---@type boolean
  local is_to_absolute = M.is_absolute(to) ---@type boolean

  if is_from_absolute and not is_to_absolute then
    return true
  end

  if is_to_absolute and not is_from_absolute then
    from = M.resolve(M.cwd(), from)
  end

  local from_pieces = M.split(from) ---@type string[]
  local to_pieces = M.split(to) ---@type string[]

  if #to_pieces < #from_pieces then
    return false
  end

  for i = 1, #from_pieces do
    if to_pieces[i] ~= from_pieces[i] then
      return false
    end
  end
  return true
end

---@param from                          string
---@param to                            string
---@return string
function M.join(from, to)
  return M.normalize(from .. SEP .. to)
end

function M.mkdir_if_nonexist(dirpath)
  if not M.is_exist(dirpath) then
    vim.fn.mkdir(dirpath, "p")
  end
end

---@param from                          string
---@param to                            string
---@param prefer_slash                  boolean
function M.relative_dir(from, to, prefer_slash)
  local is_from_absolute = M.is_absolute(from) ---@type boolean
  local is_to_absolute = M.is_absolute(to) ---@type boolean

  if is_from_absolute and not is_to_absolute then
    return M.normalize(to)
  end

  if is_to_absolute and not is_from_absolute then
    return M.normalize(to)
  end

  local from_pieces = M.split(from) ---@type string[]
  local to_pieces = M.split(to) ---@type string[]
  local L = #from_pieces < #to_pieces and #from_pieces or #to_pieces

  local i = 1
  while i < L do
    if from_pieces[i] ~= to_pieces[i] then
      break
    end
    i = i + 1
  end

  local sep = prefer_slash and "/" or SEP ---@type string
  local p = "" ---@type string
  for _ = i, #from_pieces do
    p = p .. sep .. ".." ---@type string
  end
  for j = i, #to_pieces - 1 do
    p = p .. sep .. to_pieces[j] ---@type string
  end
  return #p > 1 and string.sub(p, 2) or p
end

---@param from                          string
---@param to                            string
---@param prefer_slash                  boolean
---@return string
function M.relative(from, to, prefer_slash)
  local is_from_absolute = M.is_absolute(from) ---@type boolean
  local is_to_absolute = M.is_absolute(to) ---@type boolean

  if is_from_absolute and not is_to_absolute then
    return M.normalize(to)
  end

  if is_to_absolute and not is_from_absolute then
    return M.normalize(to)
  end

  local from_pieces = M.split(from) ---@type string[]
  local to_pieces = M.split(to) ---@type string[]
  local L = #from_pieces < #to_pieces and #from_pieces or #to_pieces

  local i = 1
  while i <= L do
    if from_pieces[i] ~= to_pieces[i] then
      break
    end
    i = i + 1
  end

  if i == 2 and is_to_absolute then
    return M.normalize(to)
  end

  local sep = prefer_slash and "/" or SEP
  local p = "" ---@type string
  for _ = i, #from_pieces do
    p = p .. sep .. ".." ---@type string
  end
  for j = i, #to_pieces do
    p = p .. sep .. to_pieces[j] ---@type string
  end

  if p == "" then
    return "."
  end
  return #p > 1 and string.sub(p, 2) or p
end

---@param cwd                           string
---@param to                            string
function M.resolve(cwd, to)
  return M.is_absolute(to) and M.normalize(to) or M.normalize(cwd .. SEP .. to)
end

---@return boolean
function M.is_repo_personal_public()
  if not IS_GIT_REPO then
    return false
  end

  local workspace = M.workspace() ---@type string
  local pieces = M.split(workspace) ---@type string[]
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
  local pieces = M.split(workspace) ---@type string[]
  return vim.list_contains(pieces, "playground")
end

---@return boolean
function M.is_repo_thirdparty()
  if not IS_GIT_REPO then
    return false
  end

  local workspace = M.workspace() ---@type string
  local pieces = M.split(workspace) ---@type string[]
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
  return M.join(HOME_NVIM_CONFIG, "../" .. app)
end

---@param filename                      string
---@return string
function M.locate_cache_filepath(filename)
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)

  local nvim_tools = require("nvim_tools")
  local hash = nvim_tools.md5(workspace_path)

  local dirpath = M.join(HOME_NVIM_CACHE, "guanghechen" .. SEP .. workspace_name .. "@" .. hash) ---@type string
  local filepath = M.join(dirpath, filename) ---@type string
  M.mkdir_if_nonexist(dirpath)
  return filepath
end

---@param filename                      string
---@return string
function M.locate_config_filepath(filename)
  return M.join(HOME_NVIM_CONFIG, filename)
end

---@param filename                      string
---@return string
function M.locate_data_filepath(filename)
  return M.join(HOME_NVIM_DATA, filename)
end

---@param filename                      string
---@return string
function M.locate_script_filepath(filename)
  return M.join(HOME_NVIM_CONFIG, "/script/" .. filename)
end

---@param filename                      string
---@return string
function M.locate_context_filepath(filename)
  return M.join(HOME_CONTEXT, filename)
end

---@param dirpath                       string
---@param candidate_filenames           string[]
---@return string|nil
function M.locate_nearest_filepath(dirpath, candidate_filenames)
  local pieces = M.split(dirpath) ---@type string[]
  for i = #pieces, 1, -1 do
    local basepath = table.concat(pieces, SEP, 1, i) ---@type string
    local stat = vim.uv.fs_stat(basepath)
    if stat ~= nil and stat.type == "directory" then
      for _, filename in ipairs(candidate_filenames) do
        local filepath = basepath .. SEP .. filename ---@type string
        if M.is_exist(filepath) then
          return filepath
        end
      end
    end
  end
  return nil
end

---@param filename                      string
---@return string
function M.locate_workspace_filepath(filename)
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)

  local nvim_tools = require("nvim_tools")
  local hash = nvim_tools.md5(workspace_path)

  local session_dir = workspace_name .. "@" .. hash ---@type string
  return M.locate_context_filepath("workspaces" .. SEP .. session_dir .. SEP .. filename)
end

return M
