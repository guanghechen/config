local DEFAULT_GIT_STATUS_HL = "f_ft_git_other"

---@enum dot.module.git.StatusEnum
local GIT_STATUS_ENUM = {
  ["!"] = 256,
  ["?"] = 2,
  A = 16,
  C = 64,
  D = 8,
  M = 4,
  R = 32,
  T = 128,
  U = 1,
}

---@type table<string, string>
local GIT_STATUS_HIGHLIGHT = {
  ["!"] = "f_ft_git_ignored",
  ["?"] = "f_ft_git_untracked",
  A = "f_ft_git_add",
  C = "f_ft_git_rename",
  D = "f_ft_git_delete",
  M = "f_ft_git_change",
  R = "f_ft_git_rename",
  T = "f_ft_git_change",
  U = "f_ft_git_unmerged",
}

---@type table<string, string[]>
local STATUS_CATEGORY_CODE_MAP = {
  ["!"] = { "ignored" },
  ["?"] = { "untracked" },
  A = { "added" },
  C = { "copied" },
  D = { "deleted" },
  M = { "modified" },
  R = { "renamed" },
  T = { "type_changed" },
  U = { "conflict" },
}

---@type string[]
local STATUS_CATEGORY_LIST = {
  "added",
  "conflict",
  "copied",
  "deleted",
  "ignored",
  "modified",
  "renamed",
  "staged",
  "type_changed",
  "unstaged",
  "untracked",
}

---@type table<string, integer>
local STATUS_CODE_BIT_MAP = {}

---@type string[]
local STATUS_CODE_ORDER = {}

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

---@class dot.module.git.status
local M = {}

M.DEFAULT_GIT_STATUS_HL = DEFAULT_GIT_STATUS_HL
M.GIT_STATUS_ENUM = GIT_STATUS_ENUM
M.GIT_STATUS_HIGHLIGHT = GIT_STATUS_HIGHLIGHT
M.STATUS_CATEGORY_CODE_MAP = STATUS_CATEGORY_CODE_MAP
M.STATUS_CATEGORY_LIST = STATUS_CATEGORY_LIST
M.STATUS_CODE_BIT_MAP = STATUS_CODE_BIT_MAP
M.STATUS_CODE_ORDER = STATUS_CODE_ORDER

---@param code                       string
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

---@param status                     string|nil
---@param other                      string|nil
---@return string|nil
function M.merge_priority_status(status, other)
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

---@param existing                   dot.module.git.StageState
---@param incoming                   dot.module.git.StageState
---@return dot.module.git.StageState
function M.combine_stage(existing, incoming)
  if incoming == nil then
    return existing
  end
  if existing == nil or existing == incoming then
    return incoming
  end
  return "mixed"
end

---@param stage_state                dot.module.git.StageState
---@param codes                      table<string, boolean>|nil
---@return table<string, boolean>
function M.collect_entry_categories(stage_state, codes)
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

---@param bits                       integer|nil
---@param codes                      table<string, boolean>|nil
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

---@param codes                      table<string, boolean>|nil
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

---@param status                     string
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

---@return table<string, table<string, boolean>>
local function create_status_groups()
  local groups = {} ---@type table<string, table<string, boolean>>
  for _, category in ipairs(STATUS_CATEGORY_LIST) do
    groups[category] = {}
  end
  return groups
end

---@param line                       string
---@return string|nil                status
---@return string|nil                relative_path
local function parse_name_status_line(line)
  if type(line) ~= "string" or #line < 3 then
    return nil, nil
  end

  local parts = vim.split(line, "\t")
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
  relative = ark.string.octal_to_utf8(relative)
  relative = dot.path.normalize(relative)

  return status, relative
end

---@param status_map                 table<string, dot.module.git.StatusEntry>
---@param absolute_path              string
---@param relative_path              string
---@return dot.module.git.StatusEntry
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

---@param entry                      dot.module.git.StatusEntry
---@param stage_key                  "staged"|"unstaged"
---@param status                     string|nil
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

---@param entry                      dot.module.git.StatusEntry
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
      summary = M.merge_priority_status(summary, code)
    end
  end

  return summary
end

---@param entry                      dot.module.git.StatusEntry
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

  entry.categories = M.collect_entry_categories(entry.stage, entry.codes)
end

---@param opts                       dot.module.git.status.ICollectOpts|nil
---@param callback                   fun(workspace: string, status_map: table<string, dot.module.git.StatusEntry>, status_groups: table<string, table<string, boolean>>)
function M.collect_async(opts, callback)
  local workspace = opts and opts.workspace or dot.path.workspace()
  if type(workspace) ~= "string" or #workspace == 0 then
    workspace = dot.path.workspace()
  end
  workspace = dot.path.normalize(workspace)
  if not dot.path.is_git_repo() then
    callback(workspace, {}, create_status_groups())
    return
  end

  local base = (opts and opts.base) or "HEAD"
  local include_untracked = opts == nil or opts.include_untracked ~= false

  local status_map = {} ---@type table<string, dot.module.git.StatusEntry>
  local status_groups = create_status_groups()

  local function finalize_all()
    for _, entry in pairs(status_map) do
      finalize_entry(entry)
      local categories = entry.categories
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
    callback(workspace, status_map, status_groups)
  end

  local function fetch_untracked()
    if not include_untracked then
      finalize_all()
      return
    end

    dot.git.cmd.run_async({ "ls-files", "--exclude-standard", "--others" }, { cwd = workspace }, function(lines, code)
      if code == 0 then
        for _, line in ipairs(lines) do
          if type(line) == "string" and #line > 0 then
            local relative = line:gsub('^"', ""):gsub('"$', "")
            relative = ark.string.octal_to_utf8(relative)
            relative = dot.path.normalize(relative)

            local absolute = dot.path.normalize(dot.path.join(workspace, relative))
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
      finalize_all()
    end)
  end

  local function fetch_unstaged()
    dot.git.cmd.run_async({ "diff", "--name-status" }, { cwd = workspace }, function(lines, code)
      if code == 0 then
        for _, line in ipairs(lines) do
          local status, relative = parse_name_status_line(line)
          if status ~= nil and relative ~= nil then
            local absolute = dot.path.normalize(dot.path.join(workspace, relative))
            local entry = ensure_entry(status_map, absolute, relative)
            apply_status_code(entry, "unstaged", status)
          end
        end
      end
      fetch_untracked()
    end)
  end

  dot.git.cmd.run_async({ "diff", "--staged", "--name-status", base, "--" }, { cwd = workspace }, function(lines, code)
    if code == 0 then
      for _, line in ipairs(lines) do
        local status, relative = parse_name_status_line(line)
        if status ~= nil and relative ~= nil then
          local absolute = dot.path.normalize(dot.path.join(workspace, relative))
          local entry = ensure_entry(status_map, absolute, relative)
          apply_status_code(entry, "staged", status)
        end
      end
    end
    fetch_unstaged()
  end)
end

---@param stage_state                dot.module.git.StageState
---@param codes                      table<string, boolean>|nil
---@param summary                    string|nil
---@param display                    string|nil
---@param categories                 table<string, boolean>|nil
---@return string|nil
function M.resolve_highlight(stage_state, codes, summary, display, categories)
  local resolved = categories ---@type table<string, boolean>|nil
  if type(resolved) ~= "table" then
    resolved = M.collect_entry_categories(stage_state, codes)
  end

  resolved = resolved or {}

  if resolved.deleted then
    return GIT_STATUS_HIGHLIGHT.D
  end
  if resolved.conflict then
    return GIT_STATUS_HIGHLIGHT.U
  end
  if resolved.unstaged then
    return "f_ft_git_unstaged"
  end
  if resolved.staged then
    return "f_ft_git_staged"
  end
  if resolved.modified then
    return GIT_STATUS_HIGHLIGHT.M
  end
  if resolved.added then
    return GIT_STATUS_HIGHLIGHT.A
  end
  if resolved.untracked then
    return GIT_STATUS_HIGHLIGHT["?"]
  end
  if resolved.ignored then
    return GIT_STATUS_HIGHLIGHT["!"]
  end

  if summary ~= nil then
    local hl = GIT_STATUS_HIGHLIGHT[summary]
    if hl ~= nil then
      return hl
    end
  end

  if display ~= nil and #display > 0 then
    return GIT_STATUS_HIGHLIGHT[display:sub(1, 1)]
  end

  return nil
end

---@param filepath                   string
---@param filetype                   "file"|"directory"|nil
---@return string|nil
---@return string|nil
function M.resolve(filepath, filetype)
  if type(filepath) ~= "string" or #filepath < 1 then
    return nil, nil
  end

  local normalized_filepath = dot.path.normalize(filepath)
  local kind = filetype or "file"
  local state_cache = dot.git.state.cache()

  if kind == "directory" then
    local display = state_cache.dir_display[normalized_filepath]
    if display == nil or #display < 1 then
      return nil, nil
    end
    local summary = state_cache.dir_summary[normalized_filepath]
    local stage_state = state_cache.dir_stage[normalized_filepath]
    local codes = state_cache.dir_codes[normalized_filepath]
    local highlight = M.resolve_highlight(stage_state, codes, summary, display, nil)
    return display, highlight
  end

  local display = state_cache.file_display[normalized_filepath]
  if display == nil or #display < 1 then
    return nil, nil
  end
  local summary = state_cache.file_summary[normalized_filepath]
  local stage_state = state_cache.file_stage[normalized_filepath]
  local entry = state_cache.status_table[normalized_filepath]
  local codes = entry and entry.codes or nil
  local categories = entry and entry.categories or nil
  local highlight = M.resolve_highlight(stage_state, codes, summary, display, categories)
  return display, highlight
end

---@param filepath                   string
---@param filetype                   "file"|"directory"|nil
---@param offset                     integer
---@param highlights                 ark.t.IHighlightInline[]
---@return string
---@return string|nil
function M.calc_info(filepath, filetype, offset, highlights)
  if type(highlights) ~= "table" then
    return "", nil
  end

  local display, highlight = M.resolve(filepath, filetype)
  if display == nil or #display < 1 then
    return "", nil
  end

  local part = " " .. display
  local leading_space_colr = offset + 1
  highlights[#highlights + 1] = { coll = offset, colr = leading_space_colr, hlname = DEFAULT_GIT_STATUS_HL }

  local status_offset = leading_space_colr
  local staged_len = 0
  local normalized_filepath = dot.path.normalize(filepath)
  local state_cache = dot.git.state.cache()
  local entry = state_cache.status_table[normalized_filepath]
  if entry ~= nil then
    staged_len = #(entry.staged_display or "")
  end
  for index = 1, #display do
    local char = display:sub(index, index)
    local hlname = GIT_STATUS_HIGHLIGHT[char] or DEFAULT_GIT_STATUS_HL
    local is_staged_char = index <= staged_len
    if is_staged_char and char ~= "D" and char ~= "U" then
      hlname = "f_ft_git_staged"
    end
    local coll = status_offset + index - 1
    local colr = coll + 1
    highlights[#highlights + 1] = { coll = coll, colr = colr, hlname = hlname }
  end

  return part, highlight
end

---@class dot.module.git.status.IAggregatedCache
---@field public dir_codes          table<string, table<string, boolean>>
---@field public dir_display        table<string, string>
---@field public dir_stage          table<string, dot.module.git.StageState>
---@field public dir_summary        table<string, string|nil>
---@field public file_display       table<string, string>
---@field public file_stage         table<string, dot.module.git.StageState>
---@field public file_summary       table<string, string|nil>
---@field public staged_files       string[]
---@field public status_table       table<string, dot.module.git.StatusEntry>
---@field public unstaged_files     string[]

---@param workspace                  string|nil
---@param status_table               table<string, dot.module.git.StatusEntry>
---@return dot.module.git.status.IAggregatedCache
function M.aggregate(workspace, status_table)
  local normalized_workspace = workspace and dot.path.normalize(workspace) or nil

  local dir_info = {} ---@type table<string, dot.module.git.state.dirinfo>
  local file_display = {} ---@type table<string, string>
  local file_stage = {} ---@type table<string, dot.module.git.StageState>
  local file_summary = {} ---@type table<string, string|nil>
  local staged_files = {} ---@type string[]
  local status_entries = {} ---@type table<string, dot.module.git.StatusEntry>
  local unstaged_files = {} ---@type string[]

  for filepath, entry in pairs(status_table) do
    if type(filepath) ~= "string" or type(entry) ~= "table" then
      goto continue
    end

    local normalized_filepath = dot.path.normalize(filepath)
    entry.path = normalized_filepath
    status_entries[normalized_filepath] = entry
    file_display[normalized_filepath] = entry.display or ""

    if entry.summary then
      file_summary[normalized_filepath] = entry.summary
    end
    if entry.stage then
      file_stage[normalized_filepath] = entry.stage
    end

    if entry.stage == "staged" or entry.stage == "mixed" then
      staged_files[#staged_files + 1] = normalized_filepath
    end
    if entry.stage == "unstaged" or entry.stage == "mixed" then
      unstaged_files[#unstaged_files + 1] = normalized_filepath
    end

    local dirpath = dot.path.dirname(normalized_filepath)
    while dirpath and #dirpath > 0 do
      local normalized_dir = dot.path.normalize(dirpath)
      local info = dir_info[normalized_dir]
      if not info then
        info = { codes = {}, stage = nil, summary = nil }
        dir_info[normalized_dir] = info
      end

      if entry.summary then
        info.summary = M.merge_priority_status(info.summary, entry.summary)
      end
      info.stage = M.combine_stage(info.stage, entry.stage)
      for code, enabled in pairs(entry.codes or {}) do
        if enabled then
          info.codes[code] = true
        end
      end

      if normalized_workspace and normalized_dir == normalized_workspace then
        break
      end

      local parent = dot.path.dirname(normalized_dir)
      if not parent or parent == "" or parent == normalized_dir then
        break
      end
      dirpath = parent
    end

    ::continue::
  end

  local dir_codes = {} ---@type table<string, table<string, boolean>>
  local dir_display_map = {} ---@type table<string, string>
  local dir_stage = {} ---@type table<string, dot.module.git.StageState>
  local dir_summary = {} ---@type table<string, string|nil>

  for dirpath, info in pairs(dir_info) do
    dir_display_map[dirpath] = M.codes_to_display(info.codes)
    if info.summary then
      dir_summary[dirpath] = info.summary
    end
    if info.stage then
      dir_stage[dirpath] = info.stage
    end
    dir_codes[dirpath] = info.codes
  end

  return {
    dir_codes = dir_codes,
    dir_display = dir_display_map,
    dir_stage = dir_stage,
    dir_summary = dir_summary,
    file_display = file_display,
    file_stage = file_stage,
    file_summary = file_summary,
    staged_files = staged_files,
    status_table = status_entries,
    unstaged_files = unstaged_files,
  }
end

function M.setup() end

return M
