---@param status                        string
---@return string
local function get_simple_git_status_code(status)
  -- Prioritize M then A over all others
  if status == "AA" or status == "DD" or status:match("U") then
    return "U"
  elseif status:match("M") then
    return "M"
  elseif status:match("[ACR]") then
    return "A"
  elseif status:match("!$") then
    return "!"
  elseif status:match("?$") then
    return "?"
  else
    local len = #status
    while len > 0 do
      local char = status:sub(len, len)
      if char ~= " " then
        return char
      end
      len = len - 1
    end
    return status
  end
end

---@param status                        string|nil
---@param other_status                  string|nil
---@return string|nil
local function get_priority_git_status_code(status, other_status)
  if not status then
    return other_status
  elseif not other_status then
    return status
  elseif status == "U" or other_status == "U" then
    return "U"
  elseif status == "?" or other_status == "?" then
    return "?"
  elseif status == "M" or other_status == "M" then
    return "M"
  elseif status == "A" or other_status == "A" then
    return "A"
  else
    return status
  end
end

---@param line                          string
---@param workspace                     string
---@param exclude_directories           boolean
---@param git_status                    table<string, string>
local parse_git_status_line = function(line, workspace, exclude_directories, git_status)
  if type(line) ~= "string" or #line < 3 then
    return
  end

  local line_parts = vim.split(line, "	")
  if #line_parts < 2 then
    return
  end

  local status = line_parts[1]
  local relative_path = line_parts[2]

  -- rename output is `R000 from/filename to/filename`
  if status:match("^R") then
    relative_path = line_parts[3]
  end

  -- remove any " due to whitespace or utf-8 in the path
  relative_path = relative_path:gsub('^"', ""):gsub('"$', "")
  -- convert octal encoded lines to utf-8
  relative_path = eve.string.octal_to_utf8(relative_path)
  -- normalize the filepath
  relative_path = eve.path.normalize(relative_path)

  local absolute_path = eve.path.join(workspace, relative_path)
  -- merge status result if there are results from multiple passes
  local existing_status = git_status[absolute_path]
  if existing_status then
    local merged = ""
    local i = 0
    while i < 2 do
      i = i + 1
      local existing_char = #existing_status >= i and existing_status:sub(i, i) or ""
      local new_char = #status >= i and status:sub(i, i) or ""
      local merged_char = get_priority_git_status_code(existing_char, new_char)
      merged = merged .. merged_char
    end
    status = merged
  end
  git_status[absolute_path] = status

  if not exclude_directories then
    local parts = eve.path.split(absolute_path) ---@type string[]
    table.remove(parts) -- pop the last part so we don't override the file's status

    local acc = "" ---@type string
    for _, part in ipairs(parts) do
      local path = acc .. eve.env.PATH_SEP .. part
      if eve.env.IS_WIN then
        path = path:gsub("^" .. eve.env.PATH_SEP, "")
      end
      local path_status = git_status[path]
      local file_status = get_simple_git_status_code(status)
      git_status[path] = get_priority_git_status_code(path_status, file_status)
      acc = path
    end
  end
end

---@class eve.viewmodel.git
local M = {}

---@param base                          string git ref base
---@param exclude_directories           boolean Whether to skip bubbling up status to directories
---@return table<string, string>
function M.status(base, exclude_directories)
  if not eve.path.is_repo_git() then
    return {}
  end

  local workspace = eve.path.workspace() ---@type string

  local cmd_staged = { "git", "-C", workspace, "diff", "--staged", "--name-status", base, "--" }
  local ok_staged, result_staged = eve.job.execute_command(cmd_staged)
  if not ok_staged then
    return {}
  end

  local cmd_unstaged = { "git", "-C", workspace, "diff", "--name-status" }
  local ok_unstaged, result_unstaged = eve.job.execute_command(cmd_unstaged)
  if not ok_unstaged then
    return {}
  end

  local cmd_untracked = { "git", "-C", workspace, "ls-files", "--exclude-standard", "--others" }
  local ok_untracked, result_untracked = eve.job.execute_command(cmd_untracked)
  if not ok_untracked then
    return {}
  end

  local git_status = {} ---@type table<string, string>

  for _, line in ipairs(result_staged) do
    parse_git_status_line(line, workspace, exclude_directories, git_status)
  end
  for _, line in ipairs(result_unstaged) do
    parse_git_status_line(line and (" " .. line) or line, workspace, exclude_directories, git_status)
  end
  for _, line in ipairs(result_untracked) do
    parse_git_status_line(line and ("?	" .. line) or line, workspace, exclude_directories, git_status)
  end

  return git_status
end

return M
