local md5 = require("fc.std.md5")
local reporter = require("fml.std.reporter")

---@class fml.std.path
local M = require("fml.std.path.mod")

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
      from = "fml.std.path",
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
      from = "fml.std.path",
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
      from = "fml.std.path",
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
      from = "fml.std.path",
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
        from = "fml.std.path",
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
