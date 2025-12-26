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
---@return fun()                     cancel_fn
function M.collect_async(opts, callback)
  local workspace = opts and opts.workspace or dot.path.workspace()
  if type(workspace) ~= "string" or #workspace == 0 then
    workspace = dot.path.workspace()
  end
  workspace = dot.path.normalize(workspace)
  if not dot.path.is_git_repo() then
    callback(workspace, {}, create_status_groups())
    return function() end
  end

  local base = (opts and opts.base) or "HEAD"
  local include_untracked = opts == nil or opts.include_untracked ~= false

  local status_map = {} ---@type table<string, dot.module.git.StatusEntry>
  local status_groups = create_status_groups()

  local pending = include_untracked and 3 or 2 ---@type integer
  local cancelled = false                  ---@type boolean
  local cancel_fns = {}                    ---@type fun()[]

  local function finalize_all()
    if not cancelled then
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
  end

  local function maybe_finalize()
    pending = pending - 1
    if pending == 0 then
      finalize_all()
    end
  end

  local cancel_fn1 = dot.git.cmd.run_async({ "diff", "--staged", "--name-status", base, "--" }, { cwd = workspace }, function(lines, code)
    if not cancelled and code == 0 then
      for _, line in ipairs(lines) do
        local status, relative = parse_name_status_line(line)
        if status ~= nil and relative ~= nil then
          local absolute = dot.path.normalize(dot.path.join(workspace, relative))
          local entry = ensure_entry(status_map, absolute, relative)
          apply_status_code(entry, "staged", status)
        end
      end
    end
    maybe_finalize()
  end)
  cancel_fns[#cancel_fns + 1] = cancel_fn1

  local cancel_fn2 = dot.git.cmd.run_async({ "diff", "--name-status" }, { cwd = workspace }, function(lines, code)
    if not cancelled and code == 0 then
      for _, line in ipairs(lines) do
        local status, relative = parse_name_status_line(line)
        if status ~= nil and relative ~= nil then
          local absolute = dot.path.normalize(dot.path.join(workspace, relative))
          local entry = ensure_entry(status_map, absolute, relative)
          apply_status_code(entry, "unstaged", status)
        end
      end
    end
    maybe_finalize()
  end)
  cancel_fns[#cancel_fns + 1] = cancel_fn2

  if include_untracked then
    local cancel_fn3 = dot.git.cmd.run_async({ "ls-files", "--exclude-standard", "--others" }, { cwd = workspace }, function(lines, code)
      if not cancelled and code == 0 then
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
      maybe_finalize()
    end)
    cancel_fns[#cancel_fns + 1] = cancel_fn3
  end

  return function()
    cancelled = true
    for _, cancel_fn in ipairs(cancel_fns) do
      cancel_fn()
    end
  end
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
  local aggregated = dot.git.state.aggregated()

  if kind == "directory" then
    local dir_info = M.compute_dir_status(aggregated, normalized_filepath)
    if not dir_info or not dir_info.display or #dir_info.display < 1 then
      return nil, nil
    end
    local highlight = M.resolve_highlight(dir_info.stage, dir_info.codes, dir_info.summary, dir_info.display, nil)
    return dir_info.display, highlight
  end

  local display = aggregated.file_display[normalized_filepath]
  if display == nil or #display < 1 then
    return nil, nil
  end
  local summary = aggregated.file_summary[normalized_filepath]
  local stage_state = aggregated.file_stage[normalized_filepath]
  local entry = aggregated.status_table[normalized_filepath]
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
  local aggregated = dot.git.state.aggregated()
  local entry = aggregated.status_table[normalized_filepath]
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

---@param workspace                  string|nil
---@param status_table               table<string, dot.module.git.StatusEntry>
---@return dot.module.git.status.IAggregatedCache
function M.aggregate(workspace, status_table)
  local normalized_workspace = workspace and dot.path.normalize(workspace) or nil

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

    ::continue::
  end

  return {
    dir_cache = {},
    file_display = file_display,
    file_stage = file_stage,
    file_summary = file_summary,
    staged_files = staged_files,
    status_table = status_entries,
    unstaged_files = unstaged_files,
    workspace = normalized_workspace,
  }
end

---@param aggregated                 dot.module.git.status.IAggregatedCache
---@param dirpath                    string
---@return dot.module.git.status.IDirInfo|nil
function M.compute_dir_status(aggregated, dirpath)
  local normalized_dir = dot.path.normalize(dirpath)

  local cached = aggregated.dir_cache[normalized_dir]
  if cached ~= nil then
    return cached or nil
  end

  local codes = {} ---@type table<string, boolean>
  local stage = nil ---@type dot.module.git.StageState
  local summary = nil ---@type string|nil
  local has_status = false ---@type boolean

  for filepath, entry in pairs(aggregated.status_table) do
    if vim.startswith(filepath, normalized_dir .. "/") then
      has_status = true
      if entry.summary then
        summary = M.merge_priority_status(summary, entry.summary)
      end
      stage = M.combine_stage(stage, entry.stage)
      for code, enabled in pairs(entry.codes or {}) do
        if enabled then
          codes[code] = true
        end
      end
    end
  end

  if not has_status then
    aggregated.dir_cache[normalized_dir] = false
    return nil
  end

  ---@type dot.module.git.status.IDirInfo
  local info = {
    codes = codes,
    display = M.codes_to_display(codes),
    stage = stage,
    summary = summary,
  }

  aggregated.dir_cache[normalized_dir] = info
  return info
end

function M.setup() end

return M
