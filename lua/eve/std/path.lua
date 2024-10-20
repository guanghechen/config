local md5 = require("eve.std.md5")
local std_os = require("eve.std.os")
local reporter = require("eve.std.reporter")

---@param category "config"|"data"|"state"
---@return string
local function resolve_home(category)
  local home = vim.fn.stdpath(category) ---@type string|string[]
  if type(home) == "string" then
    return home
  end

  if type(home) == "table" and #home > 0 then
    return home[1]
  end

  reporter.error({
    from = "eve.std.path",
    subject = "resolve_home",
    message = "Cannot resolve ''" .. category .. "' home",
    details = { category = category, home = home },
  })
  error("[eve.std.path] Cannot resolve '" .. category .. ".'")
end

local HOME_NVIM_CONFIG = resolve_home("config") ---@type string
local HOME_NVIM_DATA = resolve_home("data") ---@type string
local HOME_NVIM_STATE = resolve_home("state") ---@type string
local SEP = std_os.path_sep() ---@type string

---@class eve.std.path
---@field public HOME_NVIM_CONFIG       string
---@field public HOME_NVIM_DATA         string
---@field public HOME_NVIM_STATE        string
---@field public SEP                    string
local M = {
  HOME_NVIM_CONFIG = HOME_NVIM_CONFIG,
  HOME_NVIM_DATA = HOME_NVIM_DATA,
  HOME_NVIM_STATE = HOME_NVIM_STATE,
  SEP = SEP,
}

---@param filepath                      string
---@return string
function M.basename(filepath)
  local pieces = M.split(filepath)
  return #pieces > 0 and pieces[#pieces] or ""
end

---@param filepath                      string
---@return string
function M.dirname(filepath)
  local pieces = M.split(filepath)
  if #pieces == 1 then
    return pieces[1]
  end

  return #pieces > 0 and table.concat(pieces, SEP, 1, #pieces - 1) or ""
end

---@param filename                      string
---@return string
function M.extname(filename)
  return filename:match("%.[^.]+$") or ""
end

---@param filepath                      string
---@return boolean
function M.is_absolute(filepath)
  if std_os.is_win() then
    return string.match(filepath, "^[%a]:[\\/].*$") ~= nil
  end
  return string.sub(filepath, 1, 1) == SEP
end

---@param filepath                      string
---@return boolean
function M.is_exist(filepath)
  local stat = vim.uv.fs_stat(filepath)
  return stat ~= nil and not vim.tbl_isempty(stat)
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

---@param filepath                      string
---@return string
function M.normalize(filepath)
  return table.concat(M.split(filepath), SEP)
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

  local pieces = {} --
  for _ = i, #from_pieces do
    table.insert(pieces, "..")
  end
  for j = i, #to_pieces do
    table.insert(pieces, to_pieces[j])
  end

  local sep = prefer_slash and "/" or SEP
  return table.concat(pieces, sep)
end

---@param cwd                           string
---@param to                            string
function M.resolve(cwd, to)
  return M.is_absolute(to) and M.normalize(to) or M.normalize(cwd .. SEP .. to)
end

---@param filepath                      string
---@return string[]
function M.split(filepath)
  local pieces = {} ---@type string[]
  local pattern = "([^/\\]+)" ---@type string
  local has_prefix_sep = SEP == "/" and string.sub(filepath, 1, 1) == SEP ---@type boolean

  for piece in string.gmatch(filepath, pattern) do
    if #piece > 0 and piece ~= "." then
      if piece == ".." and (has_prefix_sep or #pieces > 0) then
        table.remove(pieces, #pieces)
      else
        table.insert(pieces, piece)
      end
    end
  end
  if has_prefix_sep then
    table.insert(pieces, 1, "")
  end
  return pieces
end

---! Check if the `to` path is under the `from` path.
---@param from                          string
---@param to                            string
---@return string[]
function M.split_prettier(from, to)
  local from_pieces = M.split(from) ---@type string[]
  local to_pieces = M.split(to) ---@type string[]
  local is_under = true ---@type boolean
  for i = 1, #from_pieces do
    if to_pieces[i] ~= from_pieces[i] then
      is_under = false
      break
    end
  end

  if is_under then
    local k = 0 ---@type integer
    local N = #to_pieces ---@type integer
    for i = #from_pieces + 1, N, 1 do
      k = k + 1
      to_pieces[k] = to_pieces[i]
    end
    for i = k + 1, N, 1 do
      to_pieces[i] = nil
    end
  end
  return to_pieces
end

---@return boolean
function M.is_git_repo()
  local cwd = vim.fn.getcwd()
  return M.locate_git_repo(cwd) ~= nil
end

---@return string
function M.workspace()
  local cwd = vim.fn.getcwd()
  return M.locate_git_repo(cwd) or cwd
end

---@return string
function M.cwd()
  local cwd = vim.fn.getcwd()
  return cwd
end

---@return string
function M.current_directory()
  return vim.fn.expand("%:p:h")
end

---@return string
function M.current_filepath()
  return vim.api.nvim_buf_get_name(0)
end

---@return string|nil
function M.locate_git_repo(filepath)
  local path_pieces = M.split(filepath) ---@type string[]
  while #path_pieces > 0 do
    local current_path = table.concat(path_pieces, SEP) ---@type string
    local git_dir_path = current_path .. SEP .. ".git" ---@type string
    if vim.fn.isdirectory(git_dir_path) ~= 0 then
      return current_path
    end
    table.remove(path_pieces, #path_pieces)
  end
  return nil
end

---@param app                           string
---@return string
function M.locate_app_config_home(app)
  local filepath = eve.path.join(HOME_NVIM_CONFIG, "../" .. app)
  return M.normalize(filepath)
end

---@param filename                      string
---@return string
function M.locate_config_filepath(filename)
  local filepath = eve.path.join(HOME_NVIM_CONFIG, "/config/" .. filename)
  return M.normalize(filepath)
end

---@param filename                      string
---@return string
function M.locate_script_filepath(filename)
  local filepath = eve.path.join(HOME_NVIM_CONFIG, "/script/" .. filename)
  return M.normalize(filepath)
end

---@param filename                      string
---@return string
function M.locate_context_filepath(filename)
  local filepath = eve.path.join(HOME_NVIM_STATE, "/guanghechen/context/" .. filename)
  return eve.path.normalize(filepath)
end

---@param filename                      string
---@return string
function M.locate_session_filepath(filename)
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = md5.sumhexa(workspace_path)
  local session_dir = workspace_name .. "@" .. hash ---@type string
  local filepath = eve.path.join(HOME_NVIM_STATE, "/guanghechen/sessions/" .. session_dir .. "/" .. filename)
  return eve.path.normalize(filepath)
end

---@param filename                      string
---@return string
function M.locate_theme_filepath(filename)
  local filepath = eve.path.join(HOME_NVIM_STATE, "/guanghechen/theme/" .. filename)
  return eve.path.normalize(filepath)
end

return M
