local DEFAULT_GIT_STATUS_HL = "m_ft_git_other"

---@enum era.m.git.StatusEnum
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
  ["!"] = "m_ft_git_ignored",
  ["?"] = "m_ft_git_untracked",
  A = "m_ft_git_add",
  C = "m_ft_git_rename",
  D = "m_ft_git_delete",
  M = "m_ft_git_change",
  R = "m_ft_git_rename",
  T = "m_ft_git_change",
  U = "m_ft_git_unmerged",
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

local next_status_bit_index = 0 ---@type integer

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

---@class era.m.git.status
local M = {}

M.DEFAULT_GIT_STATUS_HL = DEFAULT_GIT_STATUS_HL
M.GIT_STATUS_ENUM = GIT_STATUS_ENUM
M.GIT_STATUS_HIGHLIGHT = GIT_STATUS_HIGHLIGHT
M.STATUS_CATEGORY_CODE_MAP = STATUS_CATEGORY_CODE_MAP
M.STATUS_CATEGORY_LIST = STATUS_CATEGORY_LIST
M.STATUS_CODE_BIT_MAP = STATUS_CODE_BIT_MAP
M.STATUS_CODE_ORDER = STATUS_CODE_ORDER

---@param filepath                   string
---@return string
local function normalize_status_path(filepath)
  -- Git status cache keys use forward slashes on Windows. On POSIX, backslash is a legal filename
  -- byte and must not be interpreted as a separator.
  if stl.env.PATH_SEP == "\\" then
    return yoz.canonical_path.normalize(filepath, false)
  end
  if filepath ~= "/" then
    local normalized = filepath:gsub("/+$", "") ---@type string
    return normalized
  end
  return filepath
end

---@param workspace                  string
---@param relative                   string
---@return string
local function join_status_path(workspace, relative)
  local prefix = workspace:sub(-1) == "/" and workspace or (workspace .. "/")
  return prefix .. relative
end

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

---@param status                     ?string
---@param other                      ?string
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

---@param existing                   era.m.git.StageState
---@param incoming                   era.m.git.StageState
---@return era.m.git.StageState
function M.combine_stage(existing, incoming)
  if incoming == nil then
    return existing
  end
  if existing == nil or existing == incoming then
    return incoming
  end
  return "mixed"
end

---@param stage_state                era.m.git.StageState
---@param codes                      ?table<string, boolean>
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

---@param bits                       ?integer
---@param codes                      ?table<string, boolean>
---@return string
local function collect_display_from_bits(bits, codes)
  local chars = {} ---@type string[]
  local count = 0 ---@type integer

  if type(bits) == "number" and bits ~= 0 then
    for _, code in ipairs(STATUS_CODE_ORDER) do
      local flag = STATUS_CODE_BIT_MAP[code]
      if bit.band(bits, flag) ~= 0 then
        count = count + 1
        chars[count] = code == "?" and "U" or code
      end
    end
  end

  local extras = nil ---@type string[]|nil
  if type(codes) == "table" then
    for code, enabled in pairs(codes) do
      if enabled and STATUS_CODE_BIT_MAP[code] == nil then
        extras = extras or {}
        extras[#extras + 1] = code == "?" and "U" or code
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

---@param codes                      ?table<string, boolean>
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
---@return string|nil                previous_relative_path
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
  local previous = nil ---@type string|nil

  if status:match("^[RC]") then
    previous = relative
    relative = parts[3]
  end

  if type(relative) ~= "string" then
    return nil, nil
  end

  relative = relative:gsub('^"', ""):gsub('"$', "")
  relative = stl.string.octal_to_utf8(relative)
  relative = normalize_status_path(relative)
  if previous ~= nil then
    previous = previous:gsub('^"', ""):gsub('"$', "")
    previous = stl.string.octal_to_utf8(previous)
    previous = normalize_status_path(previous)
  end

  return status, relative, previous
end

---@class era.m.git.status.INameStatusRecord
---@field public new_object_name        string|nil
---@field public old_object_name        string|nil
---@field public previous               string|nil
---@field public relative               string
---@field public status                 string

---@param object_name                   string|nil
---@return string|nil
local function normalize_object_name(object_name)
  if type(object_name) ~= "string" or object_name == "" or not object_name:find("[^0]") then
    return nil
  end
  return object_name
end

---Parse name-status output, preserving literal paths from Git's NUL protocol.
---@param lines                         string[]
---@return era.m.git.status.INameStatusRecord[]
local function parse_name_status_output(lines)
  local output = table.concat(lines, "\n") ---@type string
  local records = {} ---@type era.m.git.status.INameStatusRecord[]

  if not output:find("\0", 1, true) then
    for _, line in ipairs(lines) do
      local status, relative, previous = parse_name_status_line(line)
      if status ~= nil and relative ~= nil then
        records[#records + 1] = {
          status = status,
          relative = relative,
          previous = previous,
          old_object_name = nil,
          new_object_name = nil,
        }
      end
    end
    return records
  end

  local fields = vim.split(output, "\0", { plain = true }) ---@type string[]
  local index = 1 ---@type integer
  while index <= #fields do
    local status = fields[index]
    local relative = nil ---@type string|nil
    local previous = nil ---@type string|nil
    if status:match("^[RC]") then
      previous = fields[index + 1]
      relative = fields[index + 2]
      index = index + 3
    else
      relative = fields[index + 1]
      index = index + 2
    end

    if status ~= "" and relative ~= nil and relative ~= "" then
      records[#records + 1] = {
        status = status,
        relative = relative,
        previous = previous,
        old_object_name = nil,
        new_object_name = nil,
      }
    end
  end

  return records
end

---Parse combined `--raw --numstat -z` output. Raw records precede numstat records;
---both sections use Git's NUL protocol, including separate source/destination fields for renames.
---@param lines                       string[]
---@return era.m.git.status.INameStatusRecord[] records
---@return table<string, era.m.git.status.INumstat> numstats
local function parse_raw_numstat_output(lines)
  local output = table.concat(lines, "\n") ---@type string
  local fields = vim.split(output, "\0", { plain = true }) ---@type string[]
  local records = {} ---@type era.m.git.status.INameStatusRecord[]
  local index = 1 ---@type integer

  while index <= #fields do
    local header = fields[index]
    if type(header) ~= "string" or header:sub(1, 1) ~= ":" then
      break
    end

    local old_object_name, new_object_name, status = header:match("^:%d+ %d+ (%x+) (%x+) ([^ ]+)$")
    if status == nil or status == "" or old_object_name == nil or new_object_name == nil then
      break
    end

    local code = status:sub(1, 1) ---@type string
    local previous = nil ---@type string|nil
    local relative = nil ---@type string|nil
    if code == "R" or code == "C" then
      previous = fields[index + 1]
      relative = fields[index + 2]
      index = index + 3
    else
      relative = fields[index + 1]
      index = index + 2
    end

    if type(relative) == "string" and relative ~= "" then
      records[#records + 1] = {
        status = status,
        relative = relative,
        previous = previous,
        old_object_name = normalize_object_name(old_object_name),
        new_object_name = normalize_object_name(new_object_name),
      }
    end
  end

  local numstats = {} ---@type table<string, era.m.git.status.INumstat>
  while index <= #fields do
    local record = fields[index]
    local insertions_text, deletions_text, relative = record:match("^([%d-]+)\t([%d-]+)\t(.*)$")
    if insertions_text == nil or deletions_text == nil or relative == nil then
      index = index + 1
    else
      if relative == "" then
        relative = fields[index + 2]
        index = index + 3
      else
        index = index + 1
      end

      local insertions = tonumber(insertions_text) ---@type integer|nil
      local deletions = tonumber(deletions_text) ---@type integer|nil
      if insertions and deletions and relative and relative ~= "" then
        numstats[relative] = { insertions = insertions, deletions = deletions }
      end
    end
  end

  return records, numstats
end

---Parse path-only output, preserving literal paths from Git's NUL protocol.
---@param lines                         string[]
---@return string[]
local function parse_path_output(lines)
  local output = table.concat(lines, "\n") ---@type string
  if not output:find("\0", 1, true) then
    local paths = {} ---@type string[]
    for _, line in ipairs(lines) do
      if type(line) == "string" and line ~= "" then
        local relative = line:gsub('^"', ""):gsub('"$', "")
        paths[#paths + 1] = stl.string.octal_to_utf8(relative)
      end
    end
    return paths
  end

  local paths = {} ---@type string[]
  for _, relative in ipairs(vim.split(output, "\0", { plain = true })) do
    if relative ~= "" then
      paths[#paths + 1] = relative
    end
  end
  return paths
end

---@param status_map                 table<string, era.m.git.StatusEntry>
---@param absolute_path              string
---@param relative_path              string
---@return era.m.git.StatusEntry
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
      staged_new_object_name = nil,
      staged_old_object_name = nil,
      unstaged_display = "",
      unstaged_new_object_name = nil,
      unstaged_old_object_name = nil,
    }
    status_map[absolute_path] = entry
  end
  return entry
end

---@param entry                      era.m.git.StatusEntry
---@param stage_key                  "staged"|"unstaged"
---@param status                     ?string
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

---@param entry                      era.m.git.StatusEntry
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

---@param entry                      era.m.git.StatusEntry
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

---@param opts                       ?era.m.git.status.ICollectOpts
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with era.m.git.status.ICollectResult;
---                                 rejects if any required Git query fails
function M.collect(opts, token)
  local workspace = dot.path.workspace()
  if not dot.path.is_git_repo() then
    return stl.c.Future.resolve({ status_map = {}, status_groups = create_status_groups(), numstats = nil })
  end
  local canonical_workspace = normalize_status_path(workspace) ---@type string

  local base = opts and opts.base
  local include_numstat = opts ~= nil and opts.include_numstat == true
  local include_untracked = opts == nil or opts.include_untracked ~= false

  return stl.c.Future.new(function(resolve, reject) ---@diagnostic disable-line: redundant-parameter
    if token and token:is_cancelled() then
      resolve({ status_map = {}, status_groups = create_status_groups(), numstats = nil })
      return
    end

    local function collect()
      local status_map = {} ---@type table<string, era.m.git.StatusEntry>
      local status_groups = create_status_groups()

      local staged_args = { "diff", "--staged" } ---@type string[]
      local unstaged_args = { "diff" } ---@type string[]
      if include_numstat then
        vim.list_extend(staged_args, { "--raw", "--abbrev=64", "--numstat" })
        vim.list_extend(unstaged_args, { "--raw", "--abbrev=64", "--numstat" })
      else
        staged_args[#staged_args + 1] = "--name-status"
        unstaged_args[#unstaged_args + 1] = "--name-status"
      end
      staged_args[#staged_args + 1] = "-z"
      unstaged_args[#unstaged_args + 1] = "-z"
      if base ~= nil then
        staged_args[#staged_args + 1] = base
      end
      staged_args[#staged_args + 1] = "--"
      unstaged_args[#unstaged_args + 1] = "--"

      ---@type stl.c.Future[]
      local futures = {
        stl.git.exec.exec(staged_args, { cwd = workspace, raw = true }, token),
        stl.git.exec.exec(unstaged_args, { cwd = workspace, raw = true }, token),
      }

      if include_untracked then
        futures[3] = stl.git.exec.exec(
          { "ls-files", "--exclude-standard", "--others", "-z" },
          { cwd = workspace, raw = true },
          token
        )
      end

      local results = stl.c.Future.all(futures):await()
      local labels = { "staged diff", "unstaged diff", "untracked files" } ---@type string[]
      for index = 1, #futures do
        local result = results[index] ---@type stl.git.exec.IResult|nil
        if type(result) ~= "table" or result.code ~= 0 then
          local code = type(result) == "table" and tostring(result.code) or "unknown" ---@type string
          local stderr = type(result) == "table" and vim.trim(result.stderr or "") or "" ---@type string
          local details = stderr ~= "" and (": " .. stderr) or "" ---@type string
          reject(string.format("Git status %s failed (exit %s)%s", labels[index], code, details))
          return
        end
      end

      local staged_records = nil ---@type era.m.git.status.INameStatusRecord[]|nil
      local unstaged_records = nil ---@type era.m.git.status.INameStatusRecord[]|nil
      local staged_numstats = nil ---@type table<string, era.m.git.status.INumstat>|nil
      local unstaged_numstats = nil ---@type table<string, era.m.git.status.INumstat>|nil

      -- Process staged changes (diff --staged)
      local staged_result = assert(results[1]) ---@type stl.git.exec.IResult
      if include_numstat then
        staged_records, staged_numstats = parse_raw_numstat_output(staged_result.lines)
      else
        staged_records = parse_name_status_output(staged_result.lines)
      end
      for _, record in ipairs(staged_records) do
        local relative = record.relative
        local absolute = join_status_path(canonical_workspace, relative)
        local entry = ensure_entry(status_map, absolute, relative)
        apply_status_code(entry, "staged", record.status)
        entry.staged_prev_relative = record.previous
        entry.staged_old_object_name = record.old_object_name
        entry.staged_new_object_name = record.new_object_name
      end

      -- Process unstaged changes (diff)
      local unstaged_result = assert(results[2]) ---@type stl.git.exec.IResult
      if include_numstat then
        unstaged_records, unstaged_numstats = parse_raw_numstat_output(unstaged_result.lines)
      else
        unstaged_records = parse_name_status_output(unstaged_result.lines)
      end
      for _, record in ipairs(unstaged_records) do
        local relative = record.relative
        local absolute = join_status_path(canonical_workspace, relative)
        local entry = ensure_entry(status_map, absolute, relative)
        apply_status_code(entry, "unstaged", record.status)
        entry.unstaged_prev_relative = record.previous
        entry.unstaged_old_object_name = record.old_object_name
        entry.unstaged_new_object_name = record.new_object_name
      end

      -- Process untracked files (ls-files)
      if include_untracked then
        local untracked_result = results[3] ---@type { lines: string[], code: integer }|nil
        if untracked_result and untracked_result.lines then
          for _, path in ipairs(parse_path_output(untracked_result.lines)) do
            local relative = path
            local absolute = join_status_path(canonical_workspace, relative)
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

      -- Finalize all entries
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

      local numstats = nil ---@type { staged: table<string, era.m.git.status.INumstat>, unstaged: table<string, era.m.git.status.INumstat> }|nil
      if include_numstat then
        numstats = { staged = assert(staged_numstats), unstaged = assert(unstaged_numstats) }
      end
      resolve({ status_map = status_map, status_groups = status_groups, numstats = numstats })
    end

    stl.async.run(function()
      local ok, err = xpcall(collect, debug.traceback)
      if not ok then
        reject(err)
      end
    end)
  end)
end

---@param stage_state                era.m.git.StageState
---@param codes                      ?table<string, boolean>
---@param summary                    ?string
---@param display                    ?string
---@param categories                 ?table<string, boolean>
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
    return "m_ft_git_unstaged"
  end
  if resolved.staged then
    return "m_ft_git_staged"
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

---@param aggregated                 era.m.git.status.IAggregatedCache
---@param path                       string
---@return era.m.git.StatusEntry|nil
local function nearest_untracked_ancestor(aggregated, path)
  local ancestor = path:sub(-1) == "/" and path:sub(1, -2) or path ---@type string
  while true do
    local parent = ancestor:match("^(.*)/[^/]+$") ---@type string|nil
    if parent == nil or parent == "" then
      return nil
    end
    ancestor = parent
    local entry = aggregated.status_table[ancestor] ---@type era.m.git.StatusEntry|nil
    if entry ~= nil and entry.codes and entry.codes["?"] then
      return entry
    end
  end
end

---@param filepath                   string
---@param filetype                   ?"file"|"directory"
---@return string|nil
---@return string|nil
function M.resolve(filepath, filetype)
  if type(filepath) ~= "string" or #filepath < 1 then
    return nil, nil
  end

  local normalized_filepath = normalize_status_path(filepath)
  local kind = filetype or "file"
  local aggregated = era.m.git.state.aggregated()

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
    -- A file with no status of its own may still live under an untracked directory symlink,
    -- whose descendants git never enumerates. Inherit untracked from the nearest such ancestor.
    if nearest_untracked_ancestor(aggregated, normalized_filepath) ~= nil then
      return "U", GIT_STATUS_HIGHLIGHT["?"]
    end
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
---@param filetype                   ?"file"|"directory"
---@param offset                     integer
---@param highlights                 stl.t.IHighlightInline[]
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
  local normalized_filepath = normalize_status_path(filepath)
  local aggregated = era.m.git.state.aggregated()
  local entry = aggregated.status_table[normalized_filepath]
  local is_untracked = entry ~= nil and entry.codes["?"] == true ---@type boolean
  if not is_untracked then
    if filetype == "directory" then
      local dir_info = M.compute_dir_status(aggregated, normalized_filepath) ---@type era.m.git.status.IDirInfo|nil
      is_untracked = dir_info ~= nil and dir_info.codes["?"] == true
    else
      is_untracked = nearest_untracked_ancestor(aggregated, normalized_filepath) ~= nil
    end
  end
  if entry ~= nil then
    staged_len = #(entry.staged_display or "")
  end
  for index = 1, #display do
    local char = display:sub(index, index)
    local hlname ---@type string
    if char == "U" and is_untracked then
      hlname = GIT_STATUS_HIGHLIGHT["?"]
    else
      hlname = GIT_STATUS_HIGHLIGHT[char] or DEFAULT_GIT_STATUS_HL
    end
    local is_staged_char = index <= staged_len
    if is_staged_char and char ~= "D" and char ~= "U" then
      hlname = "m_ft_git_staged"
    end
    local coll = status_offset + index - 1
    local colr = coll + 1
    highlights[#highlights + 1] = { coll = coll, colr = colr, hlname = hlname }
  end

  return part, highlight
end

---Build derived indexes from `collect`'s canonical absolute status keys.
---@param status_table               table<string, era.m.git.StatusEntry>
---@return era.m.git.status.IAggregatedCache
function M.aggregate(status_table)
  local file_display = {} ---@type table<string, string>
  local file_stage = {} ---@type table<string, era.m.git.StageState>
  local file_summary = {} ---@type table<string, string|nil>
  local staged_files = {} ---@type string[]
  local status_entries = {} ---@type table<string, era.m.git.StatusEntry>
  local unstaged_files = {} ---@type string[]

  for filepath, entry in pairs(status_table) do
    if type(filepath) ~= "string" or type(entry) ~= "table" then
      goto continue
    end

    entry.path = filepath
    status_entries[filepath] = entry
    file_display[filepath] = entry.display or ""

    if entry.summary then
      file_summary[filepath] = entry.summary
    end
    if entry.stage then
      file_stage[filepath] = entry.stage
    end

    if entry.stage == "staged" or entry.stage == "mixed" then
      staged_files[#staged_files + 1] = filepath
    end
    if entry.stage == "unstaged" or entry.stage == "mixed" then
      unstaged_files[#unstaged_files + 1] = filepath
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
  }
end

---@param aggregated                 era.m.git.status.IAggregatedCache
---@param dirpath                    string
---@return era.m.git.status.IDirInfo|nil
function M.compute_dir_status(aggregated, dirpath)
  local normalized_dir = normalize_status_path(dirpath)

  local cached = aggregated.dir_cache[normalized_dir]
  if cached ~= nil then
    return cached or nil
  end

  local codes = {} ---@type table<string, boolean>
  local stage = nil ---@type era.m.git.StageState
  local summary = nil ---@type string|nil
  local has_status = false ---@type boolean

  ---@param entry era.m.git.StatusEntry
  local function incorporate(entry)
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

  -- A directory may carry a status on its own path rather than through children -- e.g. an
  -- untracked directory symlink, which git reports at the symlink itself (it never recurses).
  local own_entry = aggregated.status_table[normalized_dir] ---@type era.m.git.StatusEntry|nil
  if own_entry ~= nil then
    incorporate(own_entry)
  end

  for filepath, entry in pairs(aggregated.status_table) do
    if vim.startswith(filepath, normalized_dir .. "/") then
      incorporate(entry)
    end
  end

  if not has_status then
    -- Inherit "untracked" from the nearest ancestor that carries it. Git reports an untracked
    -- directory symlink at the symlink's own path and never recurses into it, so descendants of
    -- the symlink have no status entries of their own yet are still untracked (e.g. a folded row
    -- like "local/warm-pool"). Ignored subtrees are dimmed separately by is_ignored, so only "?".
    local ancestor_entry = nearest_untracked_ancestor(aggregated, normalized_dir) ---@type era.m.git.StatusEntry|nil
    if ancestor_entry ~= nil then
      incorporate(ancestor_entry)
    end
  end

  if not has_status then
    aggregated.dir_cache[normalized_dir] = false
    return nil
  end

  ---@type era.m.git.status.IDirInfo
  local info = {
    codes = codes,
    display = M.codes_to_display(codes),
    stage = stage,
    summary = summary,
  }

  aggregated.dir_cache[normalized_dir] = info
  return info
end

return M
