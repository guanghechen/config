local util_os = require("guanghechen.util.os")
local util_md5 = require("guanghechen.util.md5")
local util_reporter = require("guanghechen.util.reporter")
local path_sep = util_os.get_path_sep() ---@type string

---@class guanghechen.util.path
local M = {
  sep = path_sep,
}

---@param filepath string
---@return boolean
function M.is_absolute(filepath)
  if util_os.is_windows() then
    return string.match(filepath, "^[%a]:[\\/].*$") ~= nil
  end
  return string.sub(filepath, 1, 1) == path_sep
end

---@param filepath string
---@return boolean
function M.is_exist(filepath)
  local stat = vim.uv.fs_stat(filepath)
  return stat ~= nil and not vim.tbl_isempty(stat)
end

---@param filepath string
---@return string[]
function M.split(filepath)
  local pieces = {} ---@type string[]
  local pattern = "([^/\\]+)" ---@type string
  local has_prefix_sep = path_sep == "/" and string.sub(filepath, 1, 1) == path_sep ---@type boolean

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

---@param filepath string
---@return string
function M.normalize(filepath)
  return table.concat(M.split(filepath), path_sep)
end

---@param from string
---@param to string
---@return string
function M.join(from, to)
  return M.normalize(from .. path_sep .. to)
end

function M.resolve(from, to)
  if M.is_absolute(to) then
    return M.normalize(to)
  end
  return M.normalize(from .. path_sep .. to)
end

---@param from string
---@param to string
---@return string
function M.relative(from, to)
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

  ---@diagnostic disable-next-line: unused-local
  for j = i, #from_pieces do
    table.insert(pieces, "..")
  end

  for j = i, #to_pieces do
    table.insert(pieces, to_pieces[j])
  end

  return table.concat(pieces, path_sep)
end

---@param filepath string
---@return string
function M.basename(filepath)
  local pieces = M.split(filepath)
  if #pieces > 0 then
    return pieces[#pieces]
  end
  return ""
end

---@return string|nil
function M.locate_git_repo(filepath)
  local path_pieces = M.split(filepath) ---@type string[]
  while #path_pieces > 0 do
    local current_path = table.concat(path_pieces, path_sep) ---@type string
    local git_dir_path = current_path .. path_sep .. ".git" ---@type string
    if vim.fn.isdirectory(git_dir_path) ~= 0 then
      return current_path
    end
    table.remove(path_pieces, #path_pieces)
  end
  return nil
end

---@type ... string[]
---@return string
function M.locate_config_filepath(...)
  local config_paths = vim.fn.stdpath("config")
  local config_path = type(config_paths) == "table" and config_paths[1] or config_paths

  if type(config_path) ~= "string" or #config_path < 1 then
    error("[guanghechen.util.os.get_config_filepath] bad config_path" .. vim.inspect(config_path))
    return ""
  end

  ---@cast config_path string
  return M.normalize(table.concat({ config_path, "config", ... }, path_sep))
end

---@type ... string[]
---@return string
function M.locate_context_filepath(...)
  return M.locate_state_filepath("ghc/context", ...)
end

---@type ... string[]
---@return string
function M.locate_data_filepath(...)
  local data_paths = vim.fn.stdpath("data")
  local data_path = type(data_paths) == "table" and data_paths[1] or data_paths

  if type(data_path) ~= "string" or #data_path < 1 then
    error("[guanghechen.util.os.get_data_filepath] bad data_path" .. vim.inspect(data_path))
    return ""
  end

  ---@cast data_path string
  return M.normalize(table.concat({ data_path, ... }, path_sep))
end

---@type ... string[]
---@return string
function M.locate_script_filepath(...)
  local config_paths = vim.fn.stdpath("config")
  local config_path = type(config_paths) == "table" and config_paths[1] or config_paths

  if type(config_path) ~= "string" or #config_path < 1 then
    error("[guanghechen.util.os.get_config_filepath] bad config_path" .. vim.inspect(config_path))
    return ""
  end

  ---@cast config_path string
  return M.normalize(table.concat({ config_path, "script", ... }, path_sep))
end

---@type ... string[]
---@return string
function M.locate_state_filepath(...)
  local state_paths = vim.fn.stdpath("state")
  local state_path = type(state_paths) == "table" and state_paths[1] or state_paths

  if type(state_path) ~= "string" or #state_path < 1 then
    error("[guanghechen.util.os.get_state_filepath] bad state_path" .. vim.inspect(state_path))
    return ""
  end

  ---@cast state_path string
  return M.normalize(table.concat({ state_path, ... }, path_sep))
end

---@param opts {filename: string}
---@return string
function M.locate_session_filepath(opts)
  local filename = opts.filename
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = util_md5.sumhexa(workspace_path)
  local session_dir = workspace_name .. "@" .. hash ---@type string
  local session_filename = filename ---@type string
  local session_filepath = M.locate_state_filepath("ghc/sessions", session_dir, session_filename)
  return session_filepath
end

---@param opts {filenames: string[]}
function M.remove_session_filepaths(opts)
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = util_md5.sumhexa(workspace_path)
  local session_dir = workspace_name .. "@" .. hash ---@type string
  for _, filename in ipairs(opts.filenames) do
    local session_filepath = session_dir .. path_sep .. filename
    if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
      os.remove(session_filepath)
      util_reporter.info({
        from = "path.lua",
        subject = "remove_session_filepaths",
        message = "Removed " .. session_filepath,
      })
    end
  end
end

---@param opts {filenames: string[]}
function M.remove_session_filepaths_all(opts)
  local session_root_dir = M.locate_state_filepath("ghc/sessions") ---@type string
  local pfile = io.popen('ls -a "' .. session_root_dir .. '"')
  if pfile then
    for dirname in pfile:lines() do
      if dirname then
        for _, filename in ipairs(opts.filenames) do
          local session_filepath = session_root_dir .. path_sep .. dirname .. path_sep .. filename
          if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
            os.remove(session_filepath)
            util_reporter.info({
              from = "path.lua",
              subject = "remove_session_filepaths",
              message = "Removed " .. session_filepath,
            })
          end
        end
      end
    end
  end
end

function M.workspace()
  local cwd = vim.fn.getcwd()
  return M.locate_git_repo(cwd) or cwd
end

function M.cwd()
  return vim.fn.getcwd()
end

function M.current_directory()
  return vim.fn.expand("%:p:h")
end

function M.current_filepath()
  return vim.api.nvim_buf_get_name(0)
end

return M
