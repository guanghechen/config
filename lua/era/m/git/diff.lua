---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.diff" ---@type string

local word_diff = require("yoz").git.word_diff

---@class era.m.git.diff
local M = {}

----------------------------------------------------------------------------------------------------
-- Line diff
----------------------------------------------------------------------------------------------------

---@param old_start                     integer
---@param old_count                     integer
---@param new_start                     integer
---@param new_count                     integer
---@param old_lines                     string[]
---@param new_lines                     string[]
---@param old_has_trailing_nl           boolean
---@param new_has_trailing_nl           boolean
---@return era.m.git.Hunk
local function create_hunk(
  old_start,
  old_count,
  new_start,
  new_count,
  old_lines,
  new_lines,
  old_has_trailing_nl,
  new_has_trailing_nl
)
  local removed_lines = {} ---@type string[]
  local added_lines = {} ---@type string[]

  for i = old_start, old_start + old_count - 1 do
    removed_lines[#removed_lines + 1] = old_lines[i] or ""
  end

  for i = new_start, new_start + new_count - 1 do
    added_lines[#added_lines + 1] = new_lines[i] or ""
  end

  local hunk_type ---@type era.m.git.HunkType
  if old_count == 0 then
    hunk_type = "add"
  elseif new_count == 0 then
    hunk_type = "delete"
  else
    hunk_type = "change"
  end

  local vend = new_start + math.max(new_count, 1) - 1 ---@type integer

  local removed_no_nl_at_eof = false ---@type boolean
  if old_count > 0 and not old_has_trailing_nl then
    local last_old_idx = old_start + old_count - 1 ---@type integer
    if last_old_idx >= #old_lines then
      removed_no_nl_at_eof = true
    end
  end

  local added_no_nl_at_eof = false ---@type boolean
  if new_count > 0 and not new_has_trailing_nl then
    local last_new_idx = new_start + new_count - 1 ---@type integer
    if last_new_idx >= #new_lines then
      added_no_nl_at_eof = true
    end
  end

  ---@type era.m.git.Hunk
  return {
    type = hunk_type,
    head = string.format("@@ -%d,%d +%d,%d @@", old_start, old_count, new_start, new_count),
    added = {
      start = new_start,
      count = new_count,
      lines = added_lines,
      no_nl_at_eof = added_no_nl_at_eof or nil,
    },
    removed = {
      start = old_start,
      count = old_count,
      lines = removed_lines,
      no_nl_at_eof = removed_no_nl_at_eof or nil,
    },
    vend = vend,
  }
end

---@param old_lines                     string[]
---@param new_lines                     string[]
---@return era.m.git.Hunk[]
function M.run_diff(old_lines, new_lines)
  local hunks = {} ---@type era.m.git.Hunk[]

  if #old_lines == 0 and #new_lines == 0 then
    return hunks
  end

  local old_has_trailing_nl = #old_lines > 0 and old_lines[#old_lines] == "" ---@type boolean
  local new_has_trailing_nl = #new_lines > 0 and new_lines[#new_lines] == "" ---@type boolean
  local a = table.concat(old_lines, "\n") ---@type string
  local b = table.concat(new_lines, "\n") ---@type string

  local diff_opts = { result_type = "indices", algorithm = "histogram" }
  local ok, raw = pcall(vim.text.diff, a, b, diff_opts)
  if not ok or type(raw) ~= "table" then
    return hunks
  end

  for _, result in ipairs(raw) do
    local old_start = result[1] ---@type integer
    local old_count = result[2] ---@type integer
    local new_start = result[3] ---@type integer
    local new_count = result[4] ---@type integer

    local hunk = create_hunk(
      old_start,
      old_count,
      new_start,
      new_count,
      old_lines,
      new_lines,
      old_has_trailing_nl,
      new_has_trailing_nl
    )
    hunks[#hunks + 1] = hunk
  end

  return hunks
end

---Worker function for async diff (self-contained, no external dependencies)
---Must use vim.mpack.encode to return table data from worker thread
---@type string
local DIFF_WORKER_FN = [[
return function(a, b)
  local diff_opts = { result_type = "indices", algorithm = "histogram" }
  local ok, raw = pcall(vim.text.diff, a, b, diff_opts)
  if not ok or type(raw) ~= "table" then
    return ""
  end
  return vim.mpack.encode(raw)
end
]]

---@type (fun(a: string, b: string): string)|nil
local diff_worker_fn = nil

---@param old_lines                     string[]
---@param new_lines                     string[]
---@param callback                      fun(hunks: era.m.git.Hunk[]): nil
---@return fun(): nil                   cancel_fn (注意：vim.uv.new_work 不可取消)
local function __run_diff_async__(old_lines, new_lines, callback)
  local old_has_trailing_nl = #old_lines > 0 and old_lines[#old_lines] == "" ---@type boolean
  local new_has_trailing_nl = #new_lines > 0 and new_lines[#new_lines] == "" ---@type boolean
  local a = table.concat(old_lines, "\n") ---@type string
  local b = table.concat(new_lines, "\n") ---@type string

  -- Lazy load worker function
  if not diff_worker_fn then
    diff_worker_fn = assert(loadstring(DIFF_WORKER_FN))()
  end

  local work = vim.uv.new_work(
    diff_worker_fn,
    vim.schedule_wrap(function(raw_encoded)
      if not raw_encoded or raw_encoded == "" then
        callback({})
        return
      end

      local ok, raw = pcall(vim.mpack.decode, raw_encoded)
      if not ok or type(raw) ~= "table" then
        callback({})
        return
      end

      local hunks = {} ---@type era.m.git.Hunk[]

      for _, result in ipairs(raw) do
        local old_start = result[1] ---@type integer
        local old_count = result[2] ---@type integer
        local new_start = result[3] ---@type integer
        local new_count = result[4] ---@type integer

        local hunk = create_hunk(
          old_start,
          old_count,
          new_start,
          new_count,
          old_lines,
          new_lines,
          old_has_trailing_nl,
          new_has_trailing_nl
        )
        hunks[#hunks + 1] = hunk
      end

      callback(hunks)
    end)
  )

  if work then
    work:queue(a, b)
  else
    -- Fallback to sync if worker creation fails
    callback(M.run_diff(old_lines, new_lines))
  end

  return function() end
end

---@param old_lines                     string[]
---@param new_lines                     string[]
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with era.m.git.Hunk[]
function M.run_diff_future(old_lines, new_lines, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve({})
      return
    end
    __run_diff_async__(old_lines, new_lines, function(hunks)
      resolve(hunks)
    end)
  end)
end

----------------------------------------------------------------------------------------------------
-- Hunk filtering
----------------------------------------------------------------------------------------------------

---@param a                             string[]
---@param b                             string[]
---@return boolean
local function same_lines(a, b)
  if #a ~= #b then
    return false
  end
  for index, line in ipairs(a) do
    if b[index] ~= line then
      return false
    end
  end
  return true
end

---Filter secondary HEAD-to-buffer changes the same way VS Code's QuickDiffModel does.
---@param primary                       era.m.git.Hunk[]|nil Index -> Buffer
---@param secondary                     era.m.git.Hunk[]|nil HEAD -> Buffer
---@return era.m.git.Hunk[]|nil
function M.filter_secondary(primary, secondary)
  if not secondary or #secondary == 0 then
    return nil
  end
  primary = primary or {}
  local result = {} ---@type era.m.git.Hunk[]

  ---@type table<integer, era.m.git.Hunk[]>
  local primary_by_start = {}
  for _, hunk in ipairs(primary) do
    local start = hunk.added.start ---@type integer
    local candidates = primary_by_start[start]
    if not candidates then
      candidates = {}
      primary_by_start[start] = candidates
    end
    candidates[#candidates + 1] = hunk
  end

  for _, candidate in ipairs(secondary) do
    local duplicate = false ---@type boolean
    for _, current in ipairs(primary_by_start[candidate.added.start] or {}) do
      if
        current.added.count == candidate.added.count
        and current.removed.count == candidate.removed.count
        and current.removed.no_nl_at_eof == candidate.removed.no_nl_at_eof
        and same_lines(current.removed.lines, candidate.removed.lines)
      then
        duplicate = true
        break
      end
    end
    if not duplicate then
      result[#result + 1] = candidate
    end
  end
  return #result > 0 and result or nil
end

----------------------------------------------------------------------------------------------------
-- Word diff
----------------------------------------------------------------------------------------------------

---@alias era.m.git.WordChange yoz.git.WordChange

---@class era.m.git.LineWordDiff
---@field public old_lnum               integer
---@field public new_lnum               integer
---@field public changes                era.m.git.WordChange[]

---@param old_text                      string
---@param new_text                      string
---@return era.m.git.WordChange[]
function M.compute_word_diff(old_text, new_text)
  if old_text == new_text then
    return {}
  end

  if #old_text == 0 then
    return { { old_start = 0, old_end = 0, new_start = 0, new_end = #new_text } }
  end

  if #new_text == 0 then
    return { { old_start = 0, old_end = #old_text, new_start = 0, new_end = 0 } }
  end

  local a, b = word_diff.inputs(old_text, new_text)
  local ok, raw = pcall(vim.text.diff, a, b, {
    algorithm = "histogram",
    result_type = "indices",
  })
  return word_diff.finish(old_text, new_text, ok and type(raw) == "table" and raw or nil)
end

---@param hunk                          era.m.git.Hunk
---@return era.m.git.LineWordDiff[]
function M.compute_hunk_word_diff(hunk)
  local result = {} ---@type era.m.git.LineWordDiff[]

  if hunk.type ~= "change" then
    return result
  end

  local removed = hunk.removed.lines ---@type string[]
  local added = hunk.added.lines ---@type string[]
  local min_count = math.min(#removed, #added) ---@type integer

  for i = 1, min_count do
    local word_changes = M.compute_word_diff(removed[i], added[i])
    if #word_changes > 0 then
      result[#result + 1] = {
        old_lnum = i,
        new_lnum = i,
        changes = word_changes,
      }
    end
  end

  return result
end

return M
