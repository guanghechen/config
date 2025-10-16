---@alias std.git.StageState "staged"|"unstaged"|"mixed"|nil

---@class std.git.StatusEntry
---@field public path                   string
---@field public relative               string
---@field public staged                 table<string, boolean>
---@field public unstaged               table<string, boolean>
---@field public codes                  table<string, boolean>
---@field public display                string
---@field public summary                string|nil
---@field public stage                  std.git.StageState
---@field public categories             table<string, boolean>
---@field public staged_display         string
---@field public unstaged_display       string

---@class std.git.ICollectStatusOpts
---@field base                          string|nil
---@field workspace                     string|nil
---@field include_untracked             boolean|nil

---@type table<string, integer>
local STATUS_PRIORITY = {
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

---@type table<string, string[]>
local STATUS_CATEGORY_CODE_MAP = {
  A = { "added" },
  M = { "modified" },
  D = { "deleted" },
  R = { "renamed" },
  C = { "copied" },
  T = { "type_changed" },
  U = { "conflict" },
  ["?"] = { "untracked" },
  ["!"] = { "ignored" },
}

---@type string[]
local STATUS_CATEGORY_LIST = {
  "staged",
  "unstaged",
  "added",
  "modified",
  "deleted",
  "renamed",
  "copied",
  "type_changed",
  "conflict",
  "untracked",
  "ignored",
}

---@param stage_state                   std.git.StageState
---@param codes                         table<string, boolean>|nil
---@return table<string, boolean>
local function collect_entry_categories(stage_state, codes)
  local categories = {} ---@type table<string, boolean>

  if stage_state == "staged" then
    categories.staged = true
  elseif stage_state == "unstaged" then
    categories.unstaged = true
  elseif stage_state == "mixed" then
    categories.staged = true
    categories.unstaged = true
  end

  if type(codes) == "table" then
    for code, enabled in pairs(codes) do
      if enabled then
        local mapped = STATUS_CATEGORY_CODE_MAP[code]
        if mapped ~= nil then
          for _, category in ipairs(mapped) do
            categories[category] = true
          end
        end
      end
    end
  end

  return categories
end

---@return table<string, table<string, boolean>>
local function create_status_groups()
  local groups = {} ---@type table<string, table<string, boolean>>
  for _, category in ipairs(STATUS_CATEGORY_LIST) do
    groups[category] = {}
  end
  return groups
end

---@param status                        string|nil
---@param other                         string|nil
---@return                              string|nil
local function merge_priority_status(status, other)
  if status == nil or status == "" then
    return other
  elseif other == nil or other == "" then
    return status
  elseif status == other then
    return status
  end

  local priority_status = STATUS_PRIORITY[status] or 10 ---@type integer
  local priority_other = STATUS_PRIORITY[other] or 10 ---@type integer
  if priority_other > priority_status then
    return other
  end
  return status
end

---@param line                          string
---@return string|nil                   status
---@return string|nil                   relative_path
local function parse_name_status_line(line)
  if type(line) ~= "string" or #line < 3 then
    return nil, nil
  end

  local parts = vim.split(line, "	")
  if #parts < 2 then
    return nil, nil
  end

  local status = parts[1]
  local relative = parts[2]

  if status:match("^[RC]") then
    relative = parts[3]
  end

  if type(relative) ~= "string" then
    return nil, nil
  end

  relative = relative:gsub('^"', ""):gsub('"$', "")
  relative = std.string.octal_to_utf8(relative)
  relative = std.path.normalize(relative)

  return status, relative
end

---@param status_map                    table<string, std.git.StatusEntry>
---@param absolute_path                 string
---@param relative_path                 string
---@return std.git.StatusEntry
local function ensure_entry(status_map, absolute_path, relative_path)
  local entry = status_map[absolute_path]
  if entry == nil then
    entry = {
      path = absolute_path,
      relative = relative_path,
      staged = {},
      unstaged = {},
      codes = {},
      display = "",
      summary = nil,
      stage = nil,
      categories = {},
      staged_display = "",
      unstaged_display = "",
    }
    status_map[absolute_path] = entry
  end
  return entry
end

---@param entry                         std.git.StatusEntry
---@param stage_key                     "staged"|"unstaged"
---@param status                        string|nil
local function apply_status_code(entry, stage_key, status)
  if type(status) ~= "string" or #status < 1 then
    return
  end

  local code = status:sub(1, 1) ---@type string
  if code == " " or code == "\t" then
    return
  end

  entry.codes[code] = true
  entry[stage_key][code] = true
end

---@param entry                         std.git.StatusEntry
local function finalize_entry(entry)
  local summary = nil ---@type string|nil

  for code in pairs(entry.staged) do
    summary = merge_priority_status(summary, code)
  end

  for code in pairs(entry.unstaged) do
    summary = merge_priority_status(summary, code)
  end

  local staged_chars = {} ---@type string[]
  for code, enabled in pairs(entry.staged) do
    if enabled then
      staged_chars[#staged_chars + 1] = code
    end
  end
  if #staged_chars > 1 then
    table.sort(staged_chars, function(left, right)
      local priority_left = STATUS_PRIORITY[left] or 10 ---@type integer
      local priority_right = STATUS_PRIORITY[right] or 10 ---@type integer
      if priority_left == priority_right then
        return left < right
      end
      return priority_left > priority_right
    end)
  end

  local unstaged_chars = {} ---@type string[]
  for code, enabled in pairs(entry.unstaged) do
    if enabled then
      unstaged_chars[#unstaged_chars + 1] = code
    end
  end
  if #unstaged_chars > 1 then
    table.sort(unstaged_chars, function(left, right)
      local priority_left = STATUS_PRIORITY[left] or 10 ---@type integer
      local priority_right = STATUS_PRIORITY[right] or 10 ---@type integer
      if priority_left == priority_right then
        return left < right
      end
      return priority_left > priority_right
    end)
  end

  local staged_display = table.concat(staged_chars) ---@type string
  local unstaged_display = table.concat(unstaged_chars) ---@type string

  entry.display = staged_display .. unstaged_display
  entry.summary = summary

  local has_staged = next(entry.staged) ~= nil ---@type boolean
  local has_unstaged = next(entry.unstaged) ~= nil ---@type boolean
  if has_staged and has_unstaged then
    entry.stage = "mixed"
  elseif has_staged then
    entry.stage = "staged"
  elseif has_unstaged then
    entry.stage = "unstaged"
  else
    entry.stage = nil
  end

  entry.categories = collect_entry_categories(entry.stage, entry.codes)
  entry.staged_display = staged_display
  entry.unstaged_display = unstaged_display
end

---@param opts                          std.git.ICollectStatusOpts|nil
---@return string                       workspace
---@return table<string, std.git.StatusEntry>
---@return table<string, table<string, boolean>>
local function collect_status(opts)
  local workspace = opts and opts.workspace or std.path.workspace() ---@type string
  if type(workspace) ~= "string" or #workspace == 0 then
    workspace = std.path.workspace()
  end
  workspace = std.path.normalize(workspace)
  if not std.path.is_git_repo() then
    return workspace, {}, create_status_groups()
  end

  local base = (opts and opts.base) or "HEAD" ---@type string
  local include_untracked = opts == nil or opts.include_untracked ~= false ---@type boolean

  local status_map = {} ---@type table<string, std.git.StatusEntry>
  local status_groups = create_status_groups() ---@type table<string, table<string, boolean>>

  local cmd_staged = { "git", "-C", workspace, "diff", "--staged", "--name-status", base, "--" }
  local ok_staged, staged_lines = std.job.execute_command(cmd_staged)
  if ok_staged then
    for _, line in ipairs(staged_lines) do
      local status, relative = parse_name_status_line(line)
      if status ~= nil and relative ~= nil then
        local absolute = std.path.normalize(std.path.join(workspace, relative)) ---@type string
        local entry = ensure_entry(status_map, absolute, relative)
        apply_status_code(entry, "staged", status)
      end
    end
  end

  local cmd_unstaged = { "git", "-C", workspace, "diff", "--name-status" }
  local ok_unstaged, unstaged_lines = std.job.execute_command(cmd_unstaged)
  if ok_unstaged then
    for _, line in ipairs(unstaged_lines) do
      local status, relative = parse_name_status_line(line)
      if status ~= nil and relative ~= nil then
        local absolute = std.path.normalize(std.path.join(workspace, relative)) ---@type string
        local entry = ensure_entry(status_map, absolute, relative)
        apply_status_code(entry, "unstaged", status)
      end
    end
  end

  if include_untracked then
    local cmd_untracked = { "git", "-C", workspace, "ls-files", "--exclude-standard", "--others" }
    local ok_untracked, untracked_lines = std.job.execute_command(cmd_untracked)
    if ok_untracked then
      for _, line in ipairs(untracked_lines) do
        if type(line) == "string" and #line > 0 then
          local relative = line:gsub('^"', ""):gsub('"$', "")
          relative = std.string.octal_to_utf8(relative)
          relative = std.path.normalize(relative)

          local absolute = std.path.normalize(std.path.join(workspace, relative)) ---@type string
          local entry = ensure_entry(status_map, absolute, relative)
          entry.codes["?"] = true
          entry.unstaged["?"] = true
        end
      end
    end
  end

  for _, entry in pairs(status_map) do
    finalize_entry(entry)
    local categories = entry.categories ---@type table<string, boolean>|nil
    if type(categories) == "table" then
      for category, enabled in pairs(categories) do
        if enabled then
          local bucket = status_groups[category]
          if bucket == nil then
            bucket = {}
            status_groups[category] = bucket
          end
          bucket[entry.path] = true
        end
      end
    end
  end

  return workspace, status_map, status_groups
end

---@class std.git
local M = {}

M.STATUS_PRIORITY = STATUS_PRIORITY
M.STATUS_CATEGORY_CODE_MAP = STATUS_CATEGORY_CODE_MAP
M.STATUS_CATEGORY_LIST = STATUS_CATEGORY_LIST
M.merge_priority_status = merge_priority_status
M.parse_name_status_line = parse_name_status_line
M.collect_entry_categories = collect_entry_categories
M.collect_status = collect_status

---@param existing                      std.git.StageState
---@param incoming                      std.git.StageState
---@return std.git.StageState
function M.combine_stage(existing, incoming)
  if incoming == nil then
    return existing
  end
  if existing == nil or existing == incoming then
    return incoming
  end
  return "mixed"
end

---@param codes                         table<string, boolean>|nil
---@return string
function M.codes_to_display(codes)
  if type(codes) ~= "table" then
    return ""
  end

  local chars = {} ---@type string[]
  for code, enabled in pairs(codes) do
    if enabled then
      chars[#chars + 1] = code
    end
  end

  if #chars < 1 then
    return ""
  end

  table.sort(chars, function(left, right)
    local priority_left = STATUS_PRIORITY[left] or 10 ---@type integer
    local priority_right = STATUS_PRIORITY[right] or 10 ---@type integer
    if priority_left == priority_right then
      return left < right
    end
    return priority_left > priority_right
  end)

  return table.concat(chars)
end

---@param status                        string
---@return string
function M.extract_parent_status(status)
  if type(status) ~= "string" or #status == 0 then
    return status
  end

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
  end

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

return M
