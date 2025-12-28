---@class dot.module.git.diff
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
---@return dot.module.git.Hunk
local function create_hunk(old_start, old_count, new_start, new_count, old_lines, new_lines, old_has_trailing_nl, new_has_trailing_nl)
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

  ---@type dot.module.git.Hunk
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
---@return dot.module.git.Hunk[]
function M.run_diff(old_lines, new_lines)
  local hunks = {} ---@type dot.module.git.Hunk[]

  if #old_lines == 0 and #new_lines == 0 then
    return hunks
  end

  local old_has_trailing_nl = #old_lines > 0 and old_lines[#old_lines] == "" ---@type boolean
  local new_has_trailing_nl = #new_lines > 0 and new_lines[#new_lines] == "" ---@type boolean

  local old_effective = old_lines ---@type string[]
  local new_effective = new_lines ---@type string[]

  if old_has_trailing_nl then
    old_effective = {}
    for i = 1, #old_lines - 1 do
      old_effective[i] = old_lines[i]
    end
  end

  if new_has_trailing_nl then
    new_effective = {}
    for i = 1, #new_lines - 1 do
      new_effective[i] = new_lines[i]
    end
  end

  local a = table.concat(old_effective, "\n") ---@type string
  local b = table.concat(new_effective, "\n") ---@type string

  if #old_effective > 0 then
    a = a .. "\n"
  end
  if #new_effective > 0 then
    b = b .. "\n"
  end

  local diff_opts = { result_type = "indices", algorithm = "histogram" }
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
    if new_start == 0 and new_count > 0 then
      new_start = 1
    end

    local hunk = create_hunk(old_start, old_count, new_start, new_count, old_effective, new_effective, old_has_trailing_nl, new_has_trailing_nl)
    hunks[#hunks + 1] = hunk
  end

  return hunks
end

----------------------------------------------------------------------------------------------------
-- Hunk filtering
----------------------------------------------------------------------------------------------------

---@param a                             dot.module.git.Hunk
---@param b                             dot.module.git.Hunk
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

---Filter out common hunks to compute staged-only changes.
---
---Input `a`: diff(HEAD, Buffer) - all changes from HEAD to current buffer
---Input `b`: diff(Index, Buffer) - unstaged changes only
---Output: hunks in `a` but not in `b` - staged changes only
---
---@param a                             dot.module.git.Hunk[]|nil
---@param b                             dot.module.git.Hunk[]|nil
---@return dot.module.git.Hunk[]|nil
function M.filter_common(a, b)
  if not a and not b then
    return nil
  end

  a = a or {}
  b = b or {}

  local a_i = 1 ---@type integer
  local b_i = 1 ---@type integer
  local ret = {} ---@type dot.module.git.Hunk[]

  for _ = 1, math.max(#a, #b) + 1 do
    local a_h = a[a_i] ---@type dot.module.git.Hunk|nil
    local b_h = b[b_i] ---@type dot.module.git.Hunk|nil

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

----------------------------------------------------------------------------------------------------
-- Word diff
----------------------------------------------------------------------------------------------------

---@class dot.module.git.WordChange
---@field public old_start              integer
---@field public old_end                integer
---@field public new_start              integer
---@field public new_end                integer

---@class dot.module.git.LineWordDiff
---@field public old_lnum               integer
---@field public new_lnum               integer
---@field public changes                dot.module.git.WordChange[]

---@param char                          string
---@return string
local function get_char_category(char)
  if not char or #char == 0 then
    return "other"
  end
  local byte = char:byte(1) ---@type integer
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

---@param text                          string
---@param pos                           integer
---@return boolean
local function is_word_boundary(text, pos)
  if pos <= 1 or pos > #text then
    return true
  end
  local prev_cat = get_char_category(text:sub(pos - 1, pos - 1)) ---@type string
  local curr_cat = get_char_category(text:sub(pos, pos)) ---@type string
  return prev_cat ~= curr_cat or (prev_cat == "word_lower" and curr_cat == "word_upper")
end

---@param a                             string
---@param b                             string
---@return integer[]
local function lcs_table(a, b)
  local m = #a ---@type integer
  local n = #b ---@type integer
  local width = n + 1 ---@type integer
  local dp = {} ---@type integer[]

  for j = 1, width do
    dp[j] = 0
  end

  for i = 1, m do
    local row_offset = i * width ---@type integer
    dp[row_offset + 1] = 0

    for j = 1, n do
      local idx = row_offset + j + 1 ---@type integer
      if a:sub(i, i) == b:sub(j, j) then
        dp[idx] = dp[idx - width - 1] + 1
      else
        dp[idx] = math.max(dp[idx - width], dp[idx - 1])
      end
    end
  end

  return dp
end

---@param dp                            integer[]
---@param a                             string
---@param b                             string
---@return table<integer, integer>
local function lcs_backtrack(dp, a, b)
  local matches = {} ---@type table<integer, integer>
  local i = #a ---@type integer
  local j = #b ---@type integer
  local width = #b + 1 ---@type integer

  while i > 0 and j > 0 do
    local idx = i * width + j + 1 ---@type integer
    if a:sub(i, i) == b:sub(j, j) then
      matches[i] = j
      i = i - 1
      j = j - 1
    elseif dp[idx - width] > dp[idx - 1] then
      i = i - 1
    else
      j = j - 1
    end
  end

  return matches
end

---@param old_text                      string
---@param new_text                      string
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

  local max_len = 500 ---@type integer
  local a = #old_text > max_len and old_text:sub(1, max_len) or old_text ---@type string
  local b = #new_text > max_len and new_text:sub(1, max_len) or new_text ---@type string

  local dp = lcs_table(a, b)
  local matches = lcs_backtrack(dp, a, b)

  local changes = {} ---@type dot.module.git.WordChange[]
  local old_pos = 1 ---@type integer
  local new_pos = 1 ---@type integer

  local sorted_old = {} ---@type integer[]
  for k in pairs(matches) do
    sorted_old[#sorted_old + 1] = k
  end
  table.sort(sorted_old)

  for _, old_idx in ipairs(sorted_old) do
    local new_idx = matches[old_idx] ---@type integer

    if old_pos < old_idx or new_pos < new_idx then
      local old_start = old_pos - 1 ---@type integer
      local old_end = old_idx - 1 ---@type integer
      local new_start = new_pos - 1 ---@type integer
      local new_end = new_idx - 1 ---@type integer

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
    local os = change.old_start ---@type integer
    local oe = change.old_end ---@type integer
    local ns = change.new_start ---@type integer
    local ne = change.new_end ---@type integer

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

---@param hunk                          dot.module.git.Hunk
---@return dot.module.git.LineWordDiff[]
function M.compute_hunk_word_diff(hunk)
  local result = {} ---@type dot.module.git.LineWordDiff[]

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

----------------------------------------------------------------------------------------------------

return M
