local DEFAULT_GIT_STATUS_HL = "f_ft_git_other" ---@type string
local GIT_STATUS_CACHE_TTL_MS = 1000 ---@type integer

---@type table<string, integer>
local GIT_STATUS_PRIORITY = {
  U = 90,
  ["?"] = 80,
  M = 70,
  D = 70,
  A = 60,
  R = 50,
  C = 50,
  T = 40,
  ["!"] = 30,
}

---@type table<string, string>
local GIT_STATUS_HIGHLIGHT = {
  A = "f_ft_git_add",
  M = "f_ft_git_change",
  D = "f_ft_git_delete",
  R = "f_ft_git_rename",
  C = "f_ft_git_rename",
  T = "f_ft_git_change",
  U = "f_ft_git_unmerged",
  ["?"] = "f_ft_git_untracked",
  ["!"] = "f_ft_git_ignored",
}

---@type table<string, any>
local GIT_STATUS_CACHE = {
  workspace = nil,
  file_status = {},
  file_display = {},
  file_summary = {},
  dir_display = {},
  dir_summary = {},
  timestamp = 0,
}

---@class eve.state.git
local M = {}

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
---@param git_status                    table<string, string>
local function parse_git_status_line(line, workspace, git_status)
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
  relative_path = std.string.octal_to_utf8(relative_path)
  -- normalize the filepath
  relative_path = std.path.normalize(relative_path)

  local absolute_path = std.path.join(workspace, relative_path)
  -- merge status result if there are results from multiple passes
  local existing_status = git_status[absolute_path]
  if existing_status then
    local merged = ""
    local i = 0
    while i < 2 do
      i = i + 1
      local existing_char = #existing_status >= i and string.sub(existing_status, i, i) or ""
      local new_char = #status >= i and string.sub(status, i, i) or ""
      local merged_char = get_priority_git_status_code(existing_char, new_char)
      merged = merged .. merged_char
    end
    status = merged
  end
  git_status[absolute_path] = status
end

---@return integer
local function git_status_now()
  if vim.uv.now then
    ---@diagnostic disable-next-line: undefined-field
    return vim.uv.now()
  end
  if vim.uv.hrtime then
    ---@diagnostic disable-next-line: undefined-field
    return math.floor(vim.uv.hrtime() / 1e6)
  end
  ---@diagnostic disable-next-line: undefined-field
  return math.floor(vim.fn.reltimefloat(vim.fn.reltime()) * 1000)
end

---@param status string|nil
---@param other string|nil
---@return string|nil
local function git_status_priority(status, other)
  if status == nil or status == "" then
    return other
  elseif other == nil or other == "" then
    return status
  end
  if status == other then
    return status
  end

  local priority_status = GIT_STATUS_PRIORITY[status] or 10 ---@type integer
  local priority_other = GIT_STATUS_PRIORITY[other] or 10 ---@type integer
  if priority_other > priority_status then
    return other
  else
    return status
  end
end

---@param status string
---@param fn fun(char: string): nil
local function git_status_iter_chars(status, fn)
  if type(status) ~= "string" or #status == 0 then
    return
  end
  local N = math.min(#status, 2) ---@type integer
  for index = 1, N, 1 do
    local char = status:sub(index, index) ---@type string
    if char ~= " " and char ~= "\t" then
      if char:match("%a") or char == "?" or char == "!" then
        fn(char)
      end
    end
  end
end

---@param status string
---@return string
local function git_status_build_display(status)
  local seen = {} ---@type table<string, boolean>
  local chars = {} ---@type string[]
  git_status_iter_chars(status, function(char)
    if not seen[char] then
      seen[char] = true
      chars[#chars + 1] = char
    end
  end)
  if #chars < 1 then
    return ""
  end
  return table.concat(chars)
end

---@param status string
---@return string|nil
local function git_status_summarize(status)
  local summary = nil ---@type string|nil
  git_status_iter_chars(status, function(char)
    summary = git_status_priority(summary, char)
  end)
  return summary
end

---@param map table<string, table<string, boolean>>
---@param path string
---@param display string
---@return nil
local function git_status_dir_add_display(map, path, display)
  if display == nil or #display == 0 then
    return
  end
  local set = map[path]
  if set == nil then
    set = {}
    map[path] = set
  end
  for index = 1, #display, 1 do
    local char = display:sub(index, index) ---@type string
    if char ~= " " and char ~= "\t" then
      set[char] = true
    end
  end
end

---@param set table<string, boolean>|nil
---@return string
local function git_status_dir_collect_display(set)
  if set == nil then
    return ""
  end
  local chars = {} ---@type string[]
  for char, enabled in pairs(set) do
    if enabled then
      chars[#chars + 1] = char
    end
  end
  if #chars < 1 then
    return ""
  end
  table.sort(chars, function(left, right)
    local priority_left = GIT_STATUS_PRIORITY[left] or 10 ---@type integer
    local priority_right = GIT_STATUS_PRIORITY[right] or 10 ---@type integer
    if priority_left == priority_right then
      return left < right
    end
    return priority_left > priority_right
  end)
  return table.concat(chars)
end

---@param filepath string
---@param summary string|nil
---@param display string
---@param workspace string|nil
---@param dir_display table<string, table<string, boolean>>
---@param dir_summary table<string, string>
---@return nil
local function git_status_propagate_directory(filepath, summary, display, workspace, dir_display, dir_summary)
  if summary == nil and (display == nil or #display == 0) then
    return
  end

  local dirpath = std.path.dirname(filepath) ---@type string|nil
  while dirpath ~= nil and #dirpath > 0 do
    local normalized_dir = std.path.normalize(dirpath) ---@type string
    dir_summary[normalized_dir] = git_status_priority(dir_summary[normalized_dir], summary)
    git_status_dir_add_display(dir_display, normalized_dir, display)

    if workspace ~= nil and normalized_dir == workspace then
      break
    end

    local parent = std.path.dirname(normalized_dir) ---@type string|nil
    if parent == nil or parent == "" or parent == normalized_dir then
      break
    end
    dirpath = parent
  end
end

---@param base                          string git ref base
---@return string
---@return table<string, string>
function M.status(base)
  local workspace = std.path.workspace() ---@type string

  if not std.path.is_git_repo() then
    return workspace, {}
  end

  local cmd_staged = { "git", "-C", workspace, "diff", "--staged", "--name-status", base, "--" }
  local ok_staged, result_staged = std.job.execute_command(cmd_staged)
  if not ok_staged then
    return workspace, {}
  end

  local cmd_unstaged = { "git", "-C", workspace, "diff", "--name-status" }
  local ok_unstaged, result_unstaged = std.job.execute_command(cmd_unstaged)
  if not ok_unstaged then
    return workspace, {}
  end

  local cmd_untracked = { "git", "-C", workspace, "ls-files", "--exclude-standard", "--others" }
  local ok_untracked, result_untracked = std.job.execute_command(cmd_untracked)
  if not ok_untracked then
    return workspace, {}
  end

  local git_status = {} ---@type table<string, string>

  for _, line in ipairs(result_staged) do
    parse_git_status_line(line, workspace, git_status)
  end
  for _, line in ipairs(result_unstaged) do
    parse_git_status_line(line and (" " .. line) or line, workspace, git_status)
  end
  for _, line in ipairs(result_untracked) do
    parse_git_status_line(line and ("?	" .. line) or line, workspace, git_status)
  end

  return workspace, git_status
end

---@param status                        string
---@return string
function M.extract_parent_status(status)
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
      local char = string.sub(status, len, len)
      if char ~= " " then
        return char
      end
      len = len - 1
    end
    return status
  end
end

---@param force boolean
---@return nil
local function git_status_refresh_cache(force)
  local now = git_status_now() ---@type integer
  local timestamp = GIT_STATUS_CACHE.timestamp ---@type integer
  if not force and timestamp ~= 0 and now - timestamp < GIT_STATUS_CACHE_TTL_MS then
    return
  end

  local ok, workspace, status_map = pcall(M.status, "HEAD")
  if not ok or type(status_map) ~= "table" then
    GIT_STATUS_CACHE.workspace = nil
    GIT_STATUS_CACHE.file_status = {}
    GIT_STATUS_CACHE.file_display = {}
    GIT_STATUS_CACHE.file_summary = {}
    GIT_STATUS_CACHE.dir_display = {}
    GIT_STATUS_CACHE.dir_summary = {}
    GIT_STATUS_CACHE.timestamp = now
    return
  end

  local normalized_workspace = workspace ~= nil and std.path.normalize(workspace) or nil ---@type string|nil
  local file_status = {}
  local file_display = {}
  local file_summary = {}
  local dir_display = {}
  local dir_summary = {}

  for filepath, status in pairs(status_map) do
    if type(filepath) == "string" and type(status) == "string" then
      local normalized_filepath = std.path.normalize(filepath) ---@type string
      local display = git_status_build_display(status) ---@type string
      local summary = git_status_summarize(status) ---@type string|nil

      file_status[normalized_filepath] = status
      file_display[normalized_filepath] = display
      file_summary[normalized_filepath] = summary

      git_status_propagate_directory(
        normalized_filepath,
        summary,
        display,
        normalized_workspace,
        dir_display,
        dir_summary
      )
    end
  end

  GIT_STATUS_CACHE.workspace = normalized_workspace
  GIT_STATUS_CACHE.file_status = file_status
  GIT_STATUS_CACHE.file_display = file_display
  GIT_STATUS_CACHE.file_summary = file_summary
  GIT_STATUS_CACHE.dir_display = dir_display
  GIT_STATUS_CACHE.dir_summary = dir_summary
  GIT_STATUS_CACHE.timestamp = now
end

---@param filepath string
---@param filetype "file"|"directory"|nil
---@return string|nil
---@return string|nil
local function git_status_resolve(filepath, filetype)
  if type(filepath) ~= "string" or #filepath < 1 then
    return nil, nil
  end

  git_status_refresh_cache(false)

  local normalized_filepath = std.path.normalize(filepath) ---@type string
  local kind = filetype or "file" ---@type string
  if kind == "directory" then
    local display = git_status_dir_collect_display(GIT_STATUS_CACHE.dir_display[normalized_filepath]) ---@type string
    if #display < 1 then
      return nil, nil
    end
    local summary = GIT_STATUS_CACHE.dir_summary[normalized_filepath] ---@type string|nil
    local highlight = summary ~= nil and GIT_STATUS_HIGHLIGHT[summary] or GIT_STATUS_HIGHLIGHT[display:sub(1, 1)] ---@type string|nil
    return display, highlight
  end

  local display = GIT_STATUS_CACHE.file_display[normalized_filepath] ---@type string
  if display == nil or #display < 1 then
    return nil, nil
  end
  local summary = GIT_STATUS_CACHE.file_summary[normalized_filepath] ---@type string|nil
  local highlight = summary ~= nil and GIT_STATUS_HIGHLIGHT[summary] or GIT_STATUS_HIGHLIGHT[display:sub(1, 1)] ---@type string|nil
  return display, highlight
end

---@param filepath string
---@param filetype "file"|"directory"|nil
---@return string|nil
---@return string|nil
function M.resolve_status(filepath, filetype)
  return git_status_resolve(filepath, filetype)
end

---@param filepath string
---@param filetype "file"|"directory"|nil
---@param offset integer
---@param highlights std.t.IHighlightInline[]
---@return string
function M.calc_status_info(filepath, filetype, offset, highlights)
  if type(highlights) ~= "table" then
    return ""
  end

  local display, highlight = git_status_resolve(filepath, filetype)
  if display == nil or #display < 1 then
    return "", nil
  end

  local part = " " .. display ---@type string
  local colr = offset + #part ---@type integer
  highlights[#highlights + 1] = { coll = offset, colr = colr, hlname = highlight or DEFAULT_GIT_STATUS_HL }
  return part, highlight
end

---@param force boolean|nil
---@return nil
function M.refresh_status_cache(force)
  git_status_refresh_cache(force == true)
end

return M
