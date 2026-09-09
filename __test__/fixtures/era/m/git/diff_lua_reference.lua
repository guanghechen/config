--- Frozen pre-native word-diff calculations; differential oracle only.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.git.diff_lua_reference" ---@type string

local M = {}

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

---@param text                          string
---@return string
local function bytes_as_lines(text)
  local bytes = {} ---@type string[]
  for index = 1, #text do
    bytes[index] = text:sub(index, index)
  end
  return table.concat(bytes, "\n")
end

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

  local max_len = 500 ---@type integer
  local a = #old_text > max_len and old_text:sub(1, max_len) or old_text ---@type string
  local b = #new_text > max_len and new_text:sub(1, max_len) or new_text ---@type string

  local changes = {} ---@type era.m.git.WordChange[]
  local ok, raw = pcall(vim.text.diff, bytes_as_lines(a), bytes_as_lines(b), {
    algorithm = "histogram",
    result_type = "indices",
  })
  if not ok or type(raw) ~= "table" then
    return { { old_start = 0, old_end = #a, new_start = 0, new_end = #b } }
  end

  for _, result in ipairs(raw) do
    local old_start = result[2] == 0 and result[1] or (result[1] - 1) ---@type integer
    local new_start = result[4] == 0 and result[3] or (result[3] - 1) ---@type integer
    changes[#changes + 1] = {
      old_start = old_start,
      old_end = old_start + result[2],
      new_start = new_start,
      new_end = new_start + result[4],
    }
  end

  if #changes == 0 then
    return {}
  end

  local merged = { changes[1] } ---@type era.m.git.WordChange[]
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

  local final = {} ---@type era.m.git.WordChange[]
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
    local merged2 = { final[1] } ---@type era.m.git.WordChange[]
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
