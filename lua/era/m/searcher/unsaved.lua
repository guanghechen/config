---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.searcher.unsaved" ---@type string

local BOM = "\239\187\191" ---@type string
local EOLS = { unix = "\n", dos = "\r\n", mac = "\r" } ---@type table<string, string>

---@class era.m.searcher.unsaved.IReplaceParams
---@field public bufnr                  integer
---@field public filepath               string OS path of the file the buffer holds
---@field public match_offsets          integer[] Offsets of the listed matches in the text of the file
---@field public search_pattern         string
---@field public replace_pattern        string
---@field public flag_regex             boolean
---@field public flag_case_sensitive    boolean

---@class era.m.searcher.unsaved
local M = {}

-- The offset each line of `text` starts at, lines ending at "\n" as diff takes them.
---@param text                          string
---@return integer[]
local function line_starts(text)
  local starts = { 0 } ---@type integer[]
  local at = text:find("\n", 1, true) ---@type integer|nil
  while at ~= nil do
    starts[#starts + 1] = at
    at = text:find("\n", at + 1, true)
  end
  return starts
end

-- The index of the last start at or before `offset`.
---@param starts                        integer[]
---@param offset                        integer
---@return integer
local function locate(starts, offset)
  local lo, hi = 1, #starts ---@type integer, integer
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2) ---@type integer
    if starts[mid] <= offset then
      lo = mid
    else
      hi = mid - 1
    end
  end
  return lo
end

-- Where lines `first` to `last` of the old text are in the new one, or nil when a change falls among them.
---@param hunks                         integer[][] From `vim.text.diff` with `result_type = "indices"`
---@param first                         integer
---@param last                          integer
---@return integer|nil
local function follow(hunks, first, last)
  local shift = 0 ---@type integer
  for _, hunk in ipairs(hunks) do
    local start_a, count_a, count_b = hunk[1], hunk[2], hunk[4] ---@type integer, integer, integer
    if count_a == 0 then
      -- Lines inserted after line start_a.
      if first <= start_a and start_a < last then
        return nil
      end
      if start_a < first then
        shift = shift + count_b
      end
    else
      if start_a <= last and first <= start_a + count_a - 1 then
        return nil
      end
      if start_a + count_a - 1 < first then
        shift = shift + count_b - count_a
      end
    end
  end
  return first + shift
end

---Replaces the listed matches of a file in its buffer with unsaved changes, rather than in the file, which writing the
---buffer would undo. The matches come from the file, so each is found in the buffer through the lines the changes
---left as they were, and only where the same match starts there; any other is left as it is.
---@param params                        era.m.searcher.unsaved.IReplaceParams
---@return boolean[]|nil                Whether each match was replaced
---@return string|nil                   Why none was
function M.replace(params)
  local bufnr = params.bufnr ---@type integer
  local fileencoding = vim.api.nvim_get_option_value("fileencoding", { buf = bufnr }) ---@type string
  if fileencoding ~= "" and fileencoding ~= "utf-8" then
    return nil, "not UTF-8 text"
  end
  local old = stl.fs.read_file({ filepath = params.filepath, silent = true }) ---@type string|nil
  if old == nil then
    return nil, "Failed to read the file"
  end
  if old:sub(1, 3) == BOM then
    old = old:sub(4)
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true) ---@type string[]
  local eol = EOLS[vim.api.nvim_get_option_value("fileformat", { buf = bufnr })] ---@type string
  local tail = vim.api.nvim_get_option_value("endofline", { buf = bufnr }) and eol or "" ---@type string
  local new = table.concat(lines, eol) .. tail ---@type string

  local function expand(text, offsets)
    return yoz.replace.expand_text_by_matches({
      text = text,
      search_pattern = params.search_pattern,
      replace_pattern = params.replace_pattern,
      flag_regex = params.flag_regex,
      flag_case_sensitive = params.flag_case_sensitive,
      match_offsets = offsets,
    })
  end

  local listed, listed_error = expand(old, params.match_offsets)
  if listed == nil then
    return nil, listed_error
  end

  local hunks = vim.text.diff(old, new, { result_type = "indices" }) --[[@as integer[][] ]]
  local old_starts, new_starts = line_starts(old), line_starts(new) ---@type integer[], integer[]
  local moved, moved_indices = {}, {} ---@type integer[], integer[]
  for index, found in ipairs(listed) do
    if found then
      local offset = params.match_offsets[index] ---@type integer
      local first = locate(old_starts, offset) ---@type integer
      local line = follow(hunks, first, locate(old_starts, found.oy)) ---@type integer|nil
      if line ~= nil then
        moved[#moved + 1] = offset - old_starts[first] + new_starts[line]
        moved_indices[#moved_indices + 1] = index
      end
    end
  end

  local current, current_error = expand(new, moved)
  if current == nil then
    return nil, current_error
  end

  -- Rows of the buffer start after its own line break, which is not "\n" alone in every format.
  local row_starts = {} ---@type integer[]
  local at = 0 ---@type integer
  for row, text in ipairs(lines) do
    row_starts[row] = at
    at = at + #text + #eol
  end
  row_starts[#lines + 1] = at

  ---@param offset                      integer
  ---@return integer[]|nil              0-based row and column, or nil within a line break the rows cannot split
  local function position(offset)
    local row = locate(row_starts, offset) ---@type integer
    local col = offset - row_starts[row] ---@type integer
    if row > #lines or col > #lines[row] then
      return nil
    end
    return { row - 1, col }
  end

  -- The same match is where the listed one was: same start, and the same extent.
  local edits = {} ---@type { index: integer, offset: integer, oy: integer, replacement: string }[]
  for i, found in ipairs(current) do
    local index = moved_indices[i] ---@type integer
    local was = listed[index] --[[@as yoz.replace.IExpandedMatch]]
    if found and found.oy - moved[i] == was.oy - params.match_offsets[index] then
      edits[#edits + 1] = { index = index, offset = moved[i], oy = found.oy, replacement = found.replacement }
    end
  end
  table.sort(edits, function(a, b)
    return a.offset > b.offset
  end)

  local replaced = {} ---@type boolean[]
  for index = 1, #params.match_offsets do
    replaced[index] = false
  end
  for _, edit in ipairs(edits) do
    local from, to = position(edit.offset), position(edit.oy + 1)
    if from ~= nil and to ~= nil then
      local pieces = vim.split(edit.replacement, "\n", { plain = true }) ---@type string[]
      if eol == "\r\n" then
        for i = 1, #pieces - 1 do
          pieces[i] = pieces[i]:gsub("\r$", "")
        end
      end
      vim.api.nvim_buf_set_text(bufnr, from[1], from[2], to[1], to[2], pieces)
      replaced[edit.index] = true
    end
  end
  return replaced
end

return M
