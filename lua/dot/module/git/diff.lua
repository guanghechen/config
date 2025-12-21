---@class dot.module.git.diff
local M = {}

---@param old_start                  integer
---@param old_count                  integer
---@param new_start                  integer
---@param new_count                  integer
---@param old_lines                  string[]
---@param new_lines                  string[]
---@return dot.module.git.Hunk
local function create_hunk(old_start, old_count, new_start, new_count, old_lines, new_lines)
  local removed_lines = {} ---@type string[]
  local added_lines = {} ---@type string[]

  for i = old_start, old_start + old_count - 1 do
    removed_lines[#removed_lines + 1] = old_lines[i] or ""
  end

  for i = new_start, new_start + new_count - 1 do
    added_lines[#added_lines + 1] = new_lines[i] or ""
  end

  local hunk_type ---@type dot.module.git.HunkType
  if old_count == 0 then
    hunk_type = "add"
  elseif new_count == 0 then
    hunk_type = "delete"
  else
    hunk_type = "change"
  end

  local vend = new_start + math.max(new_count, 1) - 1

  ---@type dot.module.git.Hunk
  return {
    type = hunk_type,
    head = string.format("@@ -%d,%d +%d,%d @@", old_start, old_count, new_start, new_count),
    added = {
      start = new_start,
      count = new_count,
      lines = added_lines,
    },
    removed = {
      start = old_start,
      count = old_count,
      lines = removed_lines,
    },
    vend = vend,
  }
end

--- Compare two hunks by their "added" (new file) position.
--- Used to determine if two hunks represent the same change in the new file.
---@param a                          dot.module.git.Hunk
---@param b                          dot.module.git.Hunk
---@return boolean
local function compare_new(a, b)
  if a.added.start ~= b.added.start then
    return false
  end
  if a.added.count ~= b.added.count then
    return false
  end
  for i = 1, a.added.count do
    if a.added.lines[i] ~= b.added.lines[i] then
      return false
    end
  end
  return true
end

--- Filter out common hunks between two diff results to compute staged-only changes.
---
--- This function is used to separate staged changes from unstaged changes:
--- - Input `a`: diff(HEAD, Buffer) - all changes from HEAD to current buffer
--- - Input `b`: diff(Index, Buffer) - unstaged changes only
--- - Output: hunks that are in `a` but not in `b` - staged changes only
---
--- The algorithm works by comparing hunks at the same position in the new file.
--- If a hunk exists at the same position with the same new content in both diffs,
--- it means that change is present in the buffer but not staged, so we exclude it.
---
--- Example:
---   HEAD has: "foo"
---   Index has: "bar"  (staged change)
---   Buffer has: "baz" (unstaged change on top)
---
---   diff(HEAD, Buffer) shows: foo -> baz
---   diff(Index, Buffer) shows: bar -> baz
---   filter_common removes the common "-> baz" part, leaving: foo -> bar (staged)
---
---@param a                          dot.module.git.Hunk[]|nil  HEAD vs Buffer diff
---@param b                          dot.module.git.Hunk[]|nil  Index vs Buffer diff
---@return dot.module.git.Hunk[]|nil  Staged-only changes (HEAD vs Index)
function M.filter_common(a, b)
  if not a and not b then
    return nil
  end

  a = a or {}
  b = b or {}

  local a_i = 1
  local b_i = 1
  local ret = {} ---@type dot.module.git.Hunk[]

  for _ = 1, math.max(#a, #b) + 1 do
    local a_h, b_h = a[a_i], b[b_i]

    if not a_h then
      break
    end

    if not b_h then
      for i = a_i, #a do
        ret[#ret + 1] = a[i]
      end
      break
    end

    if a_h.added.start > b_h.added.start then
      b_i = b_i + 1
    elseif a_h.added.start < b_h.added.start then
      ret[#ret + 1] = a_h
      a_i = a_i + 1
    else
      if not compare_new(a_h, b_h) then
        ret[#ret + 1] = a_h
      end
      a_i = a_i + 1
      b_i = b_i + 1
    end
  end

  return #ret > 0 and ret or nil
end

---@param old_lines                  string[]
---@param new_lines                  string[]
---@return dot.module.git.Hunk[]
function M.run_diff(old_lines, new_lines)
  local hunks = {} ---@type dot.module.git.Hunk[]

  if #old_lines == 0 and #new_lines == 0 then
    return hunks
  end

  local a = table.concat(old_lines, "\n")
  local b = table.concat(new_lines, "\n")

  if #old_lines > 0 then
    a = a .. "\n"
  end
  if #new_lines > 0 then
    b = b .. "\n"
  end

  local diff_opts = {
    result_type = "indices",
    algorithm = "histogram",
  }

  local ok, raw = pcall(vim.diff, a, b, diff_opts) ---@diagnostic disable-line: deprecated
  if not ok or type(raw) ~= "table" then
    return hunks
  end

  for _, result in ipairs(raw) do
    local old_start = result[1] ---@type integer
    local old_count = result[2] ---@type integer
    local new_start = result[3] ---@type integer
    local new_count = result[4] ---@type integer

    if old_start == 0 then
      old_start = 1
    end
    if new_start == 0 then
      new_start = 1
    end

    local hunk = create_hunk(old_start, old_count, new_start, new_count, old_lines, new_lines)
    hunks[#hunks + 1] = hunk
  end

  return hunks
end

----------------------------------------------------------------------------------------------------
-- Word diff implementation
-- Inspired by VSCode's diff algorithm which computes character-level changes within line changes
----------------------------------------------------------------------------------------------------

---@class dot.module.git.WordChange
---@field public old_start           integer  0-based byte offset in old line
---@field public old_end             integer  0-based byte offset in old line (exclusive)
---@field public new_start           integer  0-based byte offset in new line
---@field public new_end             integer  0-based byte offset in new line (exclusive)

---@class dot.module.git.LineWordDiff
---@field public old_lnum            integer  1-based line number in removed lines
---@field public new_lnum            integer  1-based line number in added lines
---@field public changes             dot.module.git.WordChange[]

--- Character categories for word boundary detection (inspired by VSCode)
---@alias dot.module.git.CharCategory
---| "word_lower"
---| "word_upper"
---| "word_number"
---| "space"
---| "separator"
---| "other"

---@param char                       string
---@return dot.module.git.CharCategory
local function get_char_category(char)
  if not char or #char == 0 then
    return "other"
  end
  local byte = char:byte(1)
  if byte >= 97 and byte <= 122 then
    return "word_lower"
  elseif byte >= 65 and byte <= 90 then
    return "word_upper"
  elseif byte >= 48 and byte <= 57 then
    return "word_number"
  elseif byte == 32 or byte == 9 then
    return "space"
  elseif byte == 44 or byte == 59 or byte == 46 or byte == 58 then
    return "separator"
  else
    return "other"
  end
end

---@param text                       string
---@param pos                        integer  1-based position
---@return boolean
local function is_word_boundary(text, pos)
  if pos <= 1 then
    return true
  end
  if pos > #text then
    return true
  end
  local prev_cat = get_char_category(text:sub(pos - 1, pos - 1))
  local curr_cat = get_char_category(text:sub(pos, pos))
  if prev_cat ~= curr_cat then
    return true
  end
  if prev_cat == "word_lower" and curr_cat == "word_upper" then
    return true
  end
  return false
end

--- Find longest common subsequence length table for two strings
---@param a                          string
---@param b                          string
---@return table<integer, table<integer, integer>>
local function lcs_table(a, b)
  local m, n = #a, #b
  local dp = {} ---@type table<integer, table<integer, integer>>

  for i = 0, m do
    dp[i] = {}
    for j = 0, n do
      dp[i][j] = 0
    end
  end

  for i = 1, m do
    for j = 1, n do
      if a:sub(i, i) == b:sub(j, j) then
        dp[i][j] = dp[i - 1][j - 1] + 1
      else
        dp[i][j] = math.max(dp[i - 1][j], dp[i][j - 1])
      end
    end
  end

  return dp
end

--- Backtrack LCS to find matching positions
---@param dp                         table<integer, table<integer, integer>>
---@param a                          string
---@param b                          string
---@return table<integer, integer>  Maps position in a (1-based) to position in b (1-based)
local function lcs_backtrack(dp, a, b)
  local matches = {} ---@type table<integer, integer>
  local i, j = #a, #b

  while i > 0 and j > 0 do
    if a:sub(i, i) == b:sub(j, j) then
      matches[i] = j
      i = i - 1
      j = j - 1
    elseif dp[i - 1][j] > dp[i][j - 1] then
      i = i - 1
    else
      j = j - 1
    end
  end

  return matches
end

--- Compute word-level diff between two strings using LCS algorithm
---@param old_text                   string
---@param new_text                   string
---@return dot.module.git.WordChange[]
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

  local max_len = 500
  local a = #old_text > max_len and old_text:sub(1, max_len) or old_text
  local b = #new_text > max_len and new_text:sub(1, max_len) or new_text

  local dp = lcs_table(a, b)
  local matches = lcs_backtrack(dp, a, b)

  local changes = {} ---@type dot.module.git.WordChange[]
  local old_pos = 1
  local new_pos = 1

  local sorted_old = {} ---@type integer[]
  for k in pairs(matches) do
    sorted_old[#sorted_old + 1] = k
  end
  table.sort(sorted_old)

  for _, old_idx in ipairs(sorted_old) do
    local new_idx = matches[old_idx]

    if old_pos < old_idx or new_pos < new_idx then
      local old_start = old_pos - 1
      local old_end = old_idx - 1
      local new_start = new_pos - 1
      local new_end = new_idx - 1

      if old_end > old_start or new_end > new_start then
        changes[#changes + 1] = {
          old_start = old_start,
          old_end = old_end,
          new_start = new_start,
          new_end = new_end,
        }
      end
    end

    old_pos = old_idx + 1
    new_pos = new_idx + 1
  end

  if old_pos <= #a or new_pos <= #b then
    changes[#changes + 1] = {
      old_start = old_pos - 1,
      old_end = #a,
      new_start = new_pos - 1,
      new_end = #b,
    }
  end

  if #changes == 0 then
    return {}
  end

  local merged = { changes[1] } ---@type dot.module.git.WordChange[]
  for i = 2, #changes do
    local prev = merged[#merged]
    local curr = changes[i]
    if curr.old_start <= prev.old_end + 2 and curr.new_start <= prev.new_end + 2 then
      prev.old_end = math.max(prev.old_end, curr.old_end)
      prev.new_end = math.max(prev.new_end, curr.new_end)
    else
      merged[#merged + 1] = curr
    end
  end

  local final = {} ---@type dot.module.git.WordChange[]
  for _, change in ipairs(merged) do
    local os, oe = change.old_start, change.old_end
    local ns, ne = change.new_start, change.new_end

    while os > 0 and not is_word_boundary(old_text, os + 1) do
      os = os - 1
    end
    while oe < #old_text and not is_word_boundary(old_text, oe + 1) do
      oe = oe + 1
    end
    while ns > 0 and not is_word_boundary(new_text, ns + 1) do
      ns = ns - 1
    end
    while ne < #new_text and not is_word_boundary(new_text, ne + 1) do
      ne = ne + 1
    end

    if oe > os or ne > ns then
      final[#final + 1] = {
        old_start = os,
        old_end = oe,
        new_start = ns,
        new_end = ne,
      }
    end
  end

  if #final > 1 then
    local merged2 = { final[1] } ---@type dot.module.git.WordChange[]
    for i = 2, #final do
      local prev = merged2[#merged2]
      local curr = final[i]
      if curr.old_start <= prev.old_end and curr.new_start <= prev.new_end then
        prev.old_end = math.max(prev.old_end, curr.old_end)
        prev.new_end = math.max(prev.new_end, curr.new_end)
      else
        merged2[#merged2 + 1] = curr
      end
    end
    final = merged2
  end

  return final
end

--- Compute word-level diff for a hunk.
--- Only computes for "change" type hunks where line counts match (1:1 correspondence).
---@param hunk                       dot.module.git.Hunk
---@return dot.module.git.LineWordDiff[]
function M.compute_hunk_word_diff(hunk)
  local result = {} ---@type dot.module.git.LineWordDiff[]

  if hunk.type ~= "change" then
    return result
  end

  local removed = hunk.removed.lines
  local added = hunk.added.lines

  if #removed ~= #added then
    local min_count = math.min(#removed, #added)
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

  for i = 1, #removed do
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
