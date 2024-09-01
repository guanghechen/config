local md5 = require("fc.std.md5")
local std_os = require("fc.std.os")
local reporter = require("fc.std.reporter")

local last_cwd = "" ---@type string
local last_cwd_pieces = {} ---@type string[]

---@class fc.std.path
---@field public SEP                    string
local M = {}

M.SEP = std_os.path_sep() ---@type string

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

  return #pieces > 0 and table.concat(pieces, M.SEP, 1, #pieces - 1) or ""
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
  return string.sub(filepath, 1, 1) == M.SEP
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
  return M.normalize(from .. M.SEP .. to)
end

function M.mkdir_if_nonexist(dirpath)
  if not M.is_exist(dirpath) then
    vim.fn.mkdir(dirpath, "p")
  end
end

---@param filepath                      string
---@return string
function M.normalize(filepath)
  return table.concat(M.split(filepath), M.SEP)
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

  local sep = prefer_slash and "/" or M.SEP
  return table.concat(pieces, sep)
end

---@param cwd                           string
---@param to                            string
function M.resolve(cwd, to)
  return M.is_absolute(to) and M.normalize(to) or M.normalize(cwd .. M.SEP .. to)
end

---@param filepath                      string
---@return string[]
function M.split(filepath)
  local pieces = {} ---@type string[]
  local pattern = "([^/\\]+)" ---@type string
  local has_prefix_sep = M.SEP == "/" and string.sub(filepath, 1, 1) == M.SEP ---@type boolean

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
---@param from_pieces                   string[]
---@param to                            string
---@return string[]
function M.split_prettier(from_pieces, to)
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
  if cwd ~= last_cwd then
    last_cwd = cwd
    last_cwd_pieces = M.split(cwd)
  end
  return cwd
end

---@return string[]
function M.get_cwd_pieces()
  return last_cwd_pieces
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
    local current_path = table.concat(path_pieces, M.SEP) ---@type string
    local git_dir_path = current_path .. M.SEP .. ".git" ---@type string
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
      from = "fc.std.path",
      subject = "locate_config_filepath",
      message = "Cannot resolve the data_paths.",
      details = { config_paths = config_paths },
    })
    return ""
  end

  ---@cast config_path string
  return M.normalize(table.concat({ config_path, "config", ... }, M.SEP))
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
      from = "fc.std.path",
      subject = "locate_data_filepath",
      message = "Cannot resolve the data_paths.",
      details = { data_paths = data_paths },
    })
    return ""
  end

  ---@cast data_path string
  return M.normalize(table.concat({ data_path, ... }, M.SEP))
end

---@type ... string[]
---@return string
function M.locate_script_filepath(...)
  local config_paths = vim.fn.stdpath("config")
  local config_path = type(config_paths) == "table" and config_paths[1] or config_paths

  if type(config_path) ~= "string" or #config_path < 1 then
    reporter.error({
      from = "fc.std.path",
      subject = "locate_script_filepath",
      message = "Cannot resolve the config_paths.",
      details = { config_paths = config_paths },
    })
    return ""
  end

  ---@cast config_path string
  return M.normalize(table.concat({ config_path, "script", ... }, M.SEP))
end

---@param opts                          { filename: string }
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
      from = "fc.std.path",
      subject = "locate_state_filepath",
      message = "Cannot resolve the state_paths.",
      details = { state_paths = state_paths },
    })
    return ""
  end

  ---@cast state_path string
  return M.normalize(table.concat({ state_path, ... }, M.SEP))
end

---@param opts {filenames: string[]}
---@return nil
function M.remove_session_filepaths(opts)
  local workspace_path = M.workspace()
  local workspace_name = (workspace_path:match("([^/\\]+)[/\\]*$") or workspace_path)
  local hash = md5.sumhexa(workspace_path)
  local session_dir = workspace_name .. "@" .. hash ---@type string
  for _, filename in ipairs(opts.filenames) do
    local session_filepath = session_dir .. M.SEP .. filename
    if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
      os.remove(session_filepath)
      reporter.info({
        from = "fc.std.path",
        subject = "remove_session_filepaths",
        message = "Removed " .. session_filepath,
      })
    end
  end
end

---@param opts {filenames: string[]}
---@return nil
function M.remove_session_filepaths_all(opts)
  local session_root_dir = M.locate_state_filepath("guanghechen/sessions") ---@type string
  local pfile = io.popen('ls -a "' .. session_root_dir .. '"')
  if pfile then
    for dirname in pfile:lines() do
      if dirname then
        for _, filename in ipairs(opts.filenames) do
          local session_filepath = session_root_dir .. M.SEP .. dirname .. M.SEP .. filename
          if session_filepath and vim.fn.filereadable(session_filepath) ~= 0 then
            os.remove(session_filepath)
            reporter.info({
              from = "fc.std.path",
              subject = "remove_session_filepaths_all",
              message = "Removed " .. session_filepath,
            })
          end
        end
      end
    end
  end
end

return M
