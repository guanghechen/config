local std_os = require("fml.std.os")
local md5 = require("fml.std.md5")
local reporter = require("fml.std.reporter")
local PATH_SEPARATOR = std_os.get_path_sep() ---@type string

---@class fml.std.path
local M = {}

---@param filepath string
---@return boolean
function M.is_absolute(filepath)
  if std_os.is_windows() then
    return string.match(filepath, "^[%a]:[\\/].*$") ~= nil
  end
  return string.sub(filepath, 1, 1) == PATH_SEPARATOR
end

---@param filepath string
---@return boolean
function M.is_exist(filepath)
  local stat = vim.uv.fs_stat(filepath)
  return stat ~= nil and not vim.tbl_isempty(stat)
end

---Check if the `to` path is under the `from` path.
---@param from string
---@param to string
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

  local from_pieces = M.split(from)
  local to_pieces = M.normalize(to)

  if #to_pieces > #from_pieces then
    return false
  end

  for i = 1, #to_pieces do
    if to_pieces[i] ~= from_pieces[i] then
      return false
    end
  end
  return true
end

---@param filepath string
---@return string[]
function M.split(filepath)
  local pieces = {} ---@type string[]
  local pattern = "([^/\\]+)" ---@type string
  local has_prefix_sep = PATH_SEPARATOR == "/" and string.sub(filepath, 1, 1) == PATH_SEPARATOR ---@type boolean

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
  return table.concat(M.split(filepath), PATH_SEPARATOR)
end

---@param from string
---@param to string
---@return string
function M.join(from, to)
  return M.normalize(from .. PATH_SEPARATOR .. to)
end

function M.resolve(from, to)
  if M.is_absolute(to) then
    return M.normalize(to)
  end
  return M.normalize(from .. PATH_SEPARATOR .. to)
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

  return table.concat(pieces, PATH_SEPARATOR)
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

---@param filepath string
---@return string
function M.extname(filepath)
  return filepath:match("^.+(%..+)$") or ""
end
---@param path_string string
---@return string[]
function M.parse_paths(path_string)
  local paths = {} ---@type string[]

  local i = 1 ---@type number
  local s = 0
  local t = 0
  while i < #path_string do
    local c = string.sub(path_string, i, i)
    if i == PATH_SEPARATOR then
      if s > 0 and t > 0 then
        local p = string.sub(path_string, s, t)
        table.insert(paths, M.normalize(p))
      end
      s = 0
      t = 0
    elseif not c:match("%s") then
      s = s == 0 and i or s
      t = i
    end
    i = i + 1
  end
  return paths
end

---@return string|nil
function M.locate_git_repo(filepath)
  local path_pieces = M.split(filepath) ---@type string[]
  while #path_pieces > 0 do
    local current_path = table.concat(path_pieces, PATH_SEPARATOR) ---@type string
    local git_dir_path = current_path .. PATH_SEPARATOR .. ".git" ---@type string
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
    reporter.error({
      from = "fml.std.path",
      subject = "locate_config_filepath",
      message = "Cannot resolve the data_paths.",
      details = { config_paths = config_paths },
    })
    return ""
  end

  ---@cast config_path string
  return M.normalize(table.concat({ config_path, "config", ... }, PATH_SEPARATOR))
end

---@param opts {filename: string}
---@return string
function M.locate_context_filepath(opts)
  local filename = opts.filename ---@type string
  return M.locate_state_filepath("guanghechen/context", filename)
end

---@type ... string[]
---@return string
function M.locate_data_filepath(...)
  local data_paths = vim.fn.stdpath("data")
  local data_path = type(data_paths) == "table" and data_paths[1] or data_paths

  if type(data_path) ~= "string" or #data_path < 1 then
    reporter.error({
      from = "fml.std.path",
      subject = "locate_data_filepath",
      message = "Cannot resolve the data_paths.",
      details = { data_paths = data_paths },
    })
    return ""
  end

  ---@cast data_path string
  return M.normalize(table.concat({ data_path, ... }, PATH_SEPARATOR))
end

---@type ... string[]
---@return string
function M.locate_script_filepath(...)
  local config_paths = vim.fn.stdpath("config")
  local config_path = type(config_paths) == "table" and config_paths[1] or config_paths

  if type(config_path) ~= "string" or #config_path < 1 then
    reporter.error({
      from = "fml.std.path",
      subject = "locate_script_filepath",
      message = "Cannot resolve the config_paths.",
      details = { config_paths = config_paths },
    })
    return ""
  end

  ---@cast config_path string
  return M.normalize(table.concat({ config_path, "script", ... }, PATH_SEPARATOR))
end

---@param opts {filename: string}
---@return string
function M.locate_session_filepath(opts)
  local filename = opts.filename
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = md5.sumhexa(workspace_path)
  local session_dir = workspace_name .. "@" .. hash ---@type string
  local session_filename = filename ---@type string
  local session_filepath = M.locate_state_filepath("guanghechen/sessions", session_dir, session_filename)
  return session_filepath
end

---@type ... string[]
---@return string
function M.locate_state_filepath(...)
  local state_paths = vim.fn.stdpath("state")
  local state_path = type(state_paths) == "table" and state_paths[1] or state_paths

  if type(state_path) ~= "string" or #state_path < 1 then
    reporter.error({
      from = "fml.std.path",
      subject = "locate_state_filepath",
      message = "Cannot resolve the state_paths.",
      details = { state_paths = state_paths },
    })
    return ""
  end

  ---@cast state_path string
  return M.normalize(table.concat({ state_path, ... }, PATH_SEPARATOR))
end

---@param opts {filenames: string[]}
function M.remove_session_filepaths(opts)
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = md5.sumhexa(workspace_path)
  local session_dir = workspace_name .. "@" .. hash ---@type string
  for _, filename in ipairs(opts.filenames) do
    local session_filepath = session_dir .. PATH_SEPARATOR .. filename
    if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
      os.remove(session_filepath)
      reporter.info({
        from = "fml.std.path",
        subject = "remove_session_filepaths",
        message = "Removed " .. session_filepath,
      })
    end
  end
end

---@param opts {filenames: string[]}
function M.remove_session_filepaths_all(opts)
  local session_root_dir = M.locate_state_filepath("guanghechen/sessions") ---@type string
  local pfile = io.popen('ls -a "' .. session_root_dir .. '"')
  if pfile then
    for dirname in pfile:lines() do
      if dirname then
        for _, filename in ipairs(opts.filenames) do
          local session_filepath = session_root_dir .. PATH_SEPARATOR .. dirname .. PATH_SEPARATOR .. filename
          if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
            os.remove(session_filepath)
            reporter.info({
              from = "fml.std.path",
              subject = "remove_session_filepaths_all",
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

