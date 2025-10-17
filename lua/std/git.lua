---@alias std.git.StageState "staged"|"unstaged"|"mixed"|nil

---@class std.git.StatusEntry
---@field public path                   string
---@field public relative               string
---@field public staged                 table<string, boolean>
---@field public unstaged               table<string, boolean>
---@field public codes                  table<string, boolean>
---@field public staged_bits            integer
---@field public unstaged_bits          integer
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

---@enum std.git.StatusEnum
local GIT_STATUS_ENUM = {
  U = 1,
  ["?"] = 2,
  M = 4,
  D = 8,
  A = 16,
  R = 32,
  C = 64,
  T = 128,
  ["!"] = 256,
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

---@type string[]
local STATUS_CODE_ORDER = {}
---@type table<string, integer>
local STATUS_CODE_BIT_MAP = {}
local next_status_bit_index = 0

do
  local items = {} ---@type { code: string, bit: integer }[]
  for code, bitflag in pairs(GIT_STATUS_ENUM) do
    items[#items + 1] = { code = code, bit = bitflag }
  end
  table.sort(items, function(left, right)
    if left.bit == right.bit then
      return left.code < right.code
    end
    return left.bit < right.bit
  end)

  for index, item in ipairs(items) do
    STATUS_CODE_ORDER[index] = item.code
    STATUS_CODE_BIT_MAP[item.code] = item.bit
  end
  next_status_bit_index = #items
end

---@type integer
local STATUS_STAGE_RELEVANT_BITS = 0
for _, code in ipairs(STATUS_CODE_ORDER) do
  if code ~= "?" and code ~= "!" then
    STATUS_STAGE_RELEVANT_BITS = bit.bor(STATUS_STAGE_RELEVANT_BITS, STATUS_CODE_BIT_MAP[code])
  end
end

---@param code                           string
---@return integer
local function ensure_status_bit(code)
  if type(code) ~= "string" or #code == 0 then
    return 0
  end

  local bitflag = STATUS_CODE_BIT_MAP[code]
  if bitflag ~= nil then
    return bitflag
  end

  next_status_bit_index = next_status_bit_index + 1
  bitflag = bit.lshift(1, next_status_bit_index - 1)
  STATUS_CODE_BIT_MAP[code] = bitflag
  STATUS_CODE_ORDER[#STATUS_CODE_ORDER + 1] = code
  if code ~= "?" and code ~= "!" then
    STATUS_STAGE_RELEVANT_BITS = bit.bor(STATUS_STAGE_RELEVANT_BITS, bitflag)
  end
  return bitflag
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

  local bit_status = ensure_status_bit(status)
  local bit_other = ensure_status_bit(other)

  if bit_other == 0 then
    return status
  end
  if bit_status == 0 then
    return other
  end

  if bit_other < bit_status then
    return other
  end
  return status
end

---@param bits                           integer|nil
---@param codes                          table<string, boolean>|nil
---@return string
local function collect_display_from_bits(bits, codes)
  local chars = {} ---@type string[]
  local count = 0 ---@type integer

  if type(bits) == "number" and bits ~= 0 then
    for _, code in ipairs(STATUS_CODE_ORDER) do
      local flag = STATUS_CODE_BIT_MAP[code]
      if bit.band(bits, flag) ~= 0 then
        count = count + 1
        chars[count] = code
      end
    end
  end

  local extras = nil ---@type string[]|nil
  if type(codes) == "table" then
    for code, enabled in pairs(codes) do
      if enabled and STATUS_CODE_BIT_MAP[code] == nil then
        extras = extras or {}
        extras[#extras + 1] = code
      end
    end
  end

  if extras ~= nil then
    table.sort(extras)
    for _, code in ipairs(extras) do
      count = count + 1
      chars[count] = code
    end
  end

  if count == 0 then
    return ""
  end

  return table.concat(chars)
end

---@param entry                          std.git.StatusEntry
---@return string|nil
local function resolve_entry_summary(entry)
  local summary_bits = bit.bor(entry.staged_bits or 0, entry.unstaged_bits or 0) ---@type integer

  if summary_bits ~= 0 then
    for _, code in ipairs(STATUS_CODE_ORDER) do
      local flag = STATUS_CODE_BIT_MAP[code]
      if bit.band(summary_bits, flag) ~= 0 then
        return code
      end
    end
  end

  local summary = nil ---@type string|nil
  for code, enabled in pairs(entry.codes) do
    if enabled then
      summary = merge_priority_status(summary, code)
    end
  end

  return summary
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
      staged_bits = 0,
      unstaged_bits = 0,
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
  local bitflag = ensure_status_bit(code)
  if bitflag ~= 0 then
    if stage_key == "staged" then
      entry.staged_bits = bit.bor(entry.staged_bits or 0, bitflag)
    else
      entry.unstaged_bits = bit.bor(entry.unstaged_bits or 0, bitflag)
    end
  end
end

---@param entry                         std.git.StatusEntry
local function finalize_entry(entry)
  local staged_bits = entry.staged_bits or 0 ---@type integer
  local unstaged_bits = entry.unstaged_bits or 0 ---@type integer

  local staged_display = collect_display_from_bits(staged_bits, entry.staged) ---@type string
  local unstaged_display = collect_display_from_bits(unstaged_bits, entry.unstaged) ---@type string

  entry.staged_display = staged_display
  entry.unstaged_display = unstaged_display
  entry.display = staged_display .. unstaged_display
  entry.summary = resolve_entry_summary(entry)

  local has_staged = bit.band(staged_bits, STATUS_STAGE_RELEVANT_BITS) ~= 0 ---@type boolean
  local has_unstaged = bit.band(unstaged_bits, STATUS_STAGE_RELEVANT_BITS) ~= 0 ---@type boolean
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
          local bitflag = ensure_status_bit("?")
          if bitflag ~= 0 then
            entry.unstaged_bits = bit.bor(entry.unstaged_bits or 0, bitflag)
          end
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

M.GIT_STATUS_ENUM = GIT_STATUS_ENUM
M.STATUS_CATEGORY_CODE_MAP = STATUS_CATEGORY_CODE_MAP
M.STATUS_CATEGORY_LIST = STATUS_CATEGORY_LIST
M.STATUS_CODE_ORDER = STATUS_CODE_ORDER
M.STATUS_CODE_BIT_MAP = STATUS_CODE_BIT_MAP
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

  local bits = 0 ---@type integer
  for code, enabled in pairs(codes) do
    if enabled then
      bits = bit.bor(bits, ensure_status_bit(code))
    end
  end

  return collect_display_from_bits(bits, codes)
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
