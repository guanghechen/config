---@class era.m.git.hunk
local M = {}

----------------------------------------------------------------------------------------------------
-- State management
----------------------------------------------------------------------------------------------------

---@type table<integer, era.m.git.Hunk[]|nil>
local buffer_hunks = {}

---@param bufnr                         integer
---@return era.m.git.Hunk[]|nil
function M.get(bufnr)
  return buffer_hunks[bufnr]
end

---@param bufnr                         integer
---@param hunks                         era.m.git.Hunk[]|nil
function M.set(bufnr, hunks)
  buffer_hunks[bufnr] = hunks
end

---@param bufnr                         integer
function M.remove(bufnr)
  buffer_hunks[bufnr] = nil
end

----------------------------------------------------------------------------------------------------
-- Hunk queries
----------------------------------------------------------------------------------------------------

---@param lnum                          integer
---@param hunks                         era.m.git.Hunk[]|nil
---@return era.m.git.Hunk|nil
---@return integer|nil
function M.find(lnum, hunks)
  if not hunks then
    return nil, nil
  end
  for i, hunk in ipairs(hunks) do
    local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
    if lnum >= effective_start and lnum <= effective_vend then
      return hunk, i
    end
  end
  return nil, nil
end

---@param lnum                          integer
---@param hunks                         era.m.git.Hunk[]|nil
---@param direction                     "next"|"prev"|"first"|"last"
---@param opts                          { wrap: boolean|nil }|nil
---@return era.m.git.Hunk|nil
---@return integer|nil
function M.find_nearest(lnum, hunks, direction, opts)
  opts = opts or {}
  if not hunks or #hunks == 0 then
    return nil, nil
  end

  if direction == "first" then
    return hunks[1], 1
  end

  if direction == "last" then
    return hunks[#hunks], #hunks
  end

  local wrap = opts.wrap ~= false

  if direction == "next" then
    for i, hunk in ipairs(hunks) do
      local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
      local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer

      if effective_vend < lnum then
        -- Continue to next hunk
      elseif effective_start > lnum then
        return hunk, i
      else
        if i + 1 <= #hunks then
          return hunks[i + 1], i + 1
        elseif wrap then
          return hunks[1], 1
        end
        return nil, nil
      end
    end
    if wrap and #hunks > 0 then
      return hunks[1], 1
    end
    return nil, nil
  end

  if direction == "prev" then
    for i = #hunks, 1, -1 do
      local hunk = hunks[i]
      local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
      if effective_vend < lnum then
        return hunk, i
      end
    end
    if wrap and #hunks > 0 then
      return hunks[#hunks], #hunks
    end
    return nil, nil
  end

  return nil, nil
end

---@param bufnr                         integer
---@return era.m.git.HunkSummary
function M.get_summary(bufnr)
  return M.summary(buffer_hunks[bufnr])
end

---@param hunks                         era.m.git.Hunk[]|nil
---@return era.m.git.HunkSummary
function M.summary(hunks)
  local added = 0 ---@type integer
  local changed = 0 ---@type integer
  local removed = 0 ---@type integer

  if hunks then
    for _, hunk in ipairs(hunks) do
      if hunk.type == "add" then
        added = added + hunk.added.count
      elseif hunk.type == "delete" then
        removed = removed + hunk.removed.count
      else
        local min_count = math.min(hunk.added.count, hunk.removed.count)
        changed = changed + min_count
        if hunk.added.count > hunk.removed.count then
          added = added + (hunk.added.count - hunk.removed.count)
        else
          removed = removed + (hunk.removed.count - hunk.added.count)
        end
      end
    end
  end

  return { added = added, changed = changed, removed = removed }
end

---Compare two hunk arrays by their heads.
---@param a                             era.m.git.Hunk[]|nil
---@param b                             era.m.git.Hunk[]|nil
---@return boolean                      true if hunks are different
function M.compare_heads(a, b)
  if (a == nil) ~= (b == nil) then
    return true
  end
  if not a or not b then
    return false
  end
  if #a ~= #b then
    return true
  end
  for i, ah in ipairs(a) do
    if b[i].head ~= ah.head then
      return true
    end
  end
  return false
end

----------------------------------------------------------------------------------------------------
-- Hunk creation
----------------------------------------------------------------------------------------------------

---@param hunks                         era.m.git.Hunk[]|nil
---@param top                           integer
---@param bot                           integer
---@return era.m.git.Hunk|nil
function M.create_partial(hunks, top, bot)
  if not hunks or #hunks == 0 then
    return nil
  end

  local dominated_hunks = {} ---@type era.m.git.Hunk[]

  for _, hunk in ipairs(hunks) do
    local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
    if not (effective_vend < top or effective_start > bot) then
      dominated_hunks[#dominated_hunks + 1] = hunk
    end
  end

  if #dominated_hunks == 0 then
    return nil
  end

  local first_hunk = dominated_hunks[1]
  local last_hunk = dominated_hunks[#dominated_hunks]

  local removed_start = first_hunk.removed.start ---@type integer
  local removed_count = 0 ---@type integer
  local first_effective_start = first_hunk.added.start == 0 and 1 or first_hunk.added.start ---@type integer
  local added_start = math.max(first_effective_start, top) ---@type integer
  local added_count = 0 ---@type integer

  local removed_lines = {} ---@type string[]
  local added_lines = {} ---@type string[]

  local includes_last_removed_line = false ---@type boolean
  local includes_last_added_line = false ---@type boolean

  for idx, hunk in ipairs(dominated_hunks) do
    local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
    local hunk_top = math.max(effective_start, top) ---@type integer
    local hunk_bot = math.min(effective_vend, bot) ---@type integer
    local is_last_hunk = (idx == #dominated_hunks) ---@type boolean

    if hunk.type == "delete" then
      for _, line in ipairs(hunk.removed.lines) do
        removed_lines[#removed_lines + 1] = line
      end
      removed_count = removed_count + hunk.removed.count
      if is_last_hunk then
        includes_last_removed_line = true
      end
    elseif hunk.type == "add" then
      local offset = hunk_top - hunk.added.start ---@type integer
      local count = hunk_bot - hunk_top + 1 ---@type integer
      for i = offset + 1, offset + count do
        added_lines[#added_lines + 1] = hunk.added.lines[i]
      end
      added_count = added_count + count
      if is_last_hunk and (offset + count >= hunk.added.count) then
        includes_last_added_line = true
      end
    else
      local add_offset = hunk_top - hunk.added.start ---@type integer
      local add_count = hunk_bot - hunk_top + 1 ---@type integer

      local remove_offset ---@type integer
      local remove_count ---@type integer

      if hunk.added.count == 0 then
        remove_offset = 0
        remove_count = hunk.removed.count
      elseif add_offset == 0 and add_count == hunk.added.count then
        remove_offset = 0
        remove_count = hunk.removed.count
      else
        local ratio = hunk.removed.count / hunk.added.count
        remove_offset = math.floor(add_offset * ratio)
        remove_count = math.ceil(add_count * ratio)
      end

      for i = remove_offset + 1, remove_offset + remove_count do
        if hunk.removed.lines[i] then
          removed_lines[#removed_lines + 1] = hunk.removed.lines[i]
        end
      end
      removed_count = removed_count + remove_count

      for i = add_offset + 1, add_offset + add_count do
        if hunk.added.lines[i] then
          added_lines[#added_lines + 1] = hunk.added.lines[i]
        end
      end
      added_count = added_count + add_count

      if is_last_hunk then
        if remove_offset + remove_count >= hunk.removed.count then
          includes_last_removed_line = true
        end
        if add_offset + add_count >= hunk.added.count then
          includes_last_added_line = true
        end
      end
    end
  end

  local hunk_type ---@type era.m.git.HunkType
  if removed_count == 0 then
    hunk_type = "add"
  elseif added_count == 0 then
    hunk_type = "delete"
  else
    hunk_type = "change"
  end

  local removed_no_nl = includes_last_removed_line and last_hunk.removed.no_nl_at_eof or nil
  local added_no_nl = includes_last_added_line and last_hunk.added.no_nl_at_eof or nil

  ---@type era.m.git.Hunk
  return {
    type = hunk_type,
    head = string.format("@@ -%d,%d +%d,%d @@", removed_start, removed_count, added_start, added_count),
    added = {
      start = added_start,
      count = added_count,
      lines = added_lines,
      no_nl_at_eof = added_no_nl,
    },
    removed = {
      start = removed_start,
      count = removed_count,
      lines = removed_lines,
      no_nl_at_eof = removed_no_nl,
    },
    vend = added_start + math.max(added_count, 1) - 1,
  }
end

---@param hunks                         era.m.git.Hunk[]|nil
---@param top                           integer
---@param bot                           integer
---@return era.m.git.Hunk[]
function M.create_partials(hunks, top, bot)
  if not hunks or #hunks == 0 then
    return {}
  end

  local result = {} ---@type era.m.git.Hunk[]

  for _, hunk in ipairs(hunks) do
    local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer

    if not (effective_vend < top or effective_start > bot) then
      local partial = M.create_partial({ hunk }, top, bot)
      if partial then
        result[#result + 1] = partial
      end
    end
  end

  return result
end

----------------------------------------------------------------------------------------------------
-- Patch generation
----------------------------------------------------------------------------------------------------

---@param relpath                       string
---@param hunk                          era.m.git.Hunk
---@param mode_bits                     string|nil
---@param invert                        boolean|nil
---@return string
function M.create_patch(relpath, hunk, mode_bits, invert)
  local lines = {} ---@type string[]
  invert = invert or false
  mode_bits = mode_bits or "100644"

  lines[#lines + 1] = string.format("diff --git a/%s b/%s", relpath, relpath)
  lines[#lines + 1] = string.format("index 000000..000000 %s", mode_bits)
  lines[#lines + 1] = string.format("--- a/%s", relpath)
  lines[#lines + 1] = string.format("+++ b/%s", relpath)

  local start = hunk.removed.start ---@type integer
  local pre_count = hunk.removed.count ---@type integer
  local now_count = hunk.added.count ---@type integer

  if hunk.type == "add" then
    start = start + 1
  end

  local pre_lines = hunk.removed.lines ---@type string[]
  local now_lines = hunk.added.lines ---@type string[]
  local pre_no_nl = hunk.removed.no_nl_at_eof ---@type boolean|nil
  local now_no_nl = hunk.added.no_nl_at_eof ---@type boolean|nil

  if invert then
    pre_count, now_count = now_count, pre_count
    pre_lines, now_lines = now_lines, pre_lines
    pre_no_nl, now_no_nl = now_no_nl, pre_no_nl
  end

  lines[#lines + 1] = string.format("@@ -%d,%d +%d,%d @@", start, pre_count, start, now_count)

  for _, line in ipairs(pre_lines) do
    lines[#lines + 1] = "-" .. line
  end

  if pre_no_nl and #pre_lines > 0 then
    lines[#lines + 1] = "\\ No newline at end of file"
  end

  for _, line in ipairs(now_lines) do
    lines[#lines + 1] = "+" .. line
  end

  if now_no_nl and #now_lines > 0 then
    lines[#lines + 1] = "\\ No newline at end of file"
  end

  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end

---@param relpath                       string
---@param hunks                         era.m.git.Hunk[]
---@param mode_bits                     string|nil
---@param invert                        boolean|nil
---@return string
function M.create_patch_multi(relpath, hunks, mode_bits, invert)
  if #hunks == 0 then
    return ""
  end

  if #hunks == 1 then
    return M.create_patch(relpath, hunks[1], mode_bits, invert)
  end

  local lines = {} ---@type string[]
  invert = invert or false
  mode_bits = mode_bits or "100644"

  lines[#lines + 1] = string.format("diff --git a/%s b/%s", relpath, relpath)
  lines[#lines + 1] = string.format("index 000000..000000 %s", mode_bits)
  lines[#lines + 1] = string.format("--- a/%s", relpath)
  lines[#lines + 1] = string.format("+++ b/%s", relpath)

  local offset = 0 ---@type integer

  for _, hunk in ipairs(hunks) do
    local start = hunk.removed.start ---@type integer
    local pre_count = hunk.removed.count ---@type integer
    local now_count = hunk.added.count ---@type integer

    if hunk.type == "add" then
      start = start + 1
    end

    local pre_lines = hunk.removed.lines ---@type string[]
    local now_lines = hunk.added.lines ---@type string[]
    local pre_no_nl = hunk.removed.no_nl_at_eof ---@type boolean|nil
    local now_no_nl = hunk.added.no_nl_at_eof ---@type boolean|nil

    if invert then
      pre_count, now_count = now_count, pre_count
      pre_lines, now_lines = now_lines, pre_lines
      pre_no_nl, now_no_nl = now_no_nl, pre_no_nl
    end

    lines[#lines + 1] = string.format("@@ -%d,%d +%d,%d @@", start, pre_count, start + offset, now_count)

    for _, line in ipairs(pre_lines) do
      lines[#lines + 1] = "-" .. line
    end

    if pre_no_nl and #pre_lines > 0 then
      lines[#lines + 1] = "\\ No newline at end of file"
    end

    for _, line in ipairs(now_lines) do
      lines[#lines + 1] = "+" .. line
    end

    if now_no_nl and #now_lines > 0 then
      lines[#lines + 1] = "\\ No newline at end of file"
    end

    offset = offset + (now_count - pre_count)
  end

  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------------------
-- Sign calculation
----------------------------------------------------------------------------------------------------

---@param hunk                          era.m.git.Hunk
---@param min_lnum                      integer|nil
---@param max_lnum                      integer|nil
---@param next_hunk                     era.m.git.Hunk|nil
---@return era.m.git.Sign[]
function M.calc_signs(hunk, min_lnum, max_lnum, next_hunk)
  local signs = {} ---@type era.m.git.Sign[]
  min_lnum = min_lnum or 1
  max_lnum = max_lnum or math.huge

  local start = hunk.added.start ---@type integer
  local count = hunk.added.count ---@type integer
  local removed_count = hunk.removed.count ---@type integer

  if count == 0 then
    if start == 0 then
      if 1 >= min_lnum and 1 <= max_lnum then
        signs[#signs + 1] = { type = "topdelete", lnum = 1, count = removed_count }
      end
    else
      if start >= min_lnum and start <= max_lnum then
        signs[#signs + 1] = { type = "delete", lnum = start, count = removed_count }
      end
    end
  else
    local is_change_hunk = hunk.type == "change" ---@type boolean
    local next_is_adjacent_delete = next_hunk and next_hunk.type == "delete" and next_hunk.added.start == start + count
    local has_extra_removes = is_change_hunk and removed_count > count

    for i = 0, count - 1 do
      local lnum = start + i ---@type integer
      if lnum >= min_lnum and lnum <= max_lnum then
        local is_last_line = (i == count - 1) ---@type boolean

        if is_last_line and is_change_hunk and (next_is_adjacent_delete or has_extra_removes) then
          signs[#signs + 1] = { type = "changedelete", lnum = lnum }
        elseif is_change_hunk and i < removed_count then
          signs[#signs + 1] = { type = "change", lnum = lnum }
        else
          signs[#signs + 1] = { type = "add", lnum = lnum }
        end
      end
    end
  end

  return signs
end

---@param hunks                         era.m.git.Hunk[]|nil
---@param min_lnum                      integer|nil
---@param max_lnum                      integer|nil
---@return era.m.git.Sign[]
function M.calc_signs_all(hunks, min_lnum, max_lnum)
  local signs = {} ---@type era.m.git.Sign[]
  if not hunks then
    return signs
  end

  max_lnum = max_lnum or math.huge

  for i, hunk in ipairs(hunks) do
    local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    if effective_start > max_lnum then
      break
    end

    local next_hunk = hunks[i + 1] ---@type era.m.git.Hunk|nil
    local hunk_signs = M.calc_signs(hunk, min_lnum, max_lnum, next_hunk)
    for _, sign in ipairs(hunk_signs) do
      signs[#signs + 1] = sign
    end
  end

  return signs
end

----------------------------------------------------------------------------------------------------
-- User actions
----------------------------------------------------------------------------------------------------

---@param range                         { [1]: integer, [2]: integer }|nil
---@return stl.c.Future                 Resolves with { ok: boolean, err: string|nil }
function M.stage(range)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not era.m.git.buffer.is_attached(bufnr) then
    era.m.git.buffer.attach(bufnr)
  end
  return era.m.git.buffer.stage_hunk(bufnr, range)
end

---@param range                         { [1]: integer, [2]: integer }|nil
---@return stl.c.Future                 Resolves with { ok: boolean, err: string|nil }
function M.unstage(range)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not era.m.git.buffer.is_attached(bufnr) then
    era.m.git.buffer.attach(bufnr)
  end
  return era.m.git.buffer.unstage_hunk(bufnr, range)
end

---@param range                         { [1]: integer, [2]: integer }|nil
---@return boolean
---@return string|nil
function M.reset(range)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not era.m.git.buffer.is_attached(bufnr) then
    era.m.git.buffer.attach(bufnr)
  end
  return era.m.git.buffer.reset_hunk(bufnr, range)
end

---@return stl.c.Future                 Resolves with boolean (success)
function M.stage_buffer()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not era.m.git.buffer.is_attached(bufnr) then
    era.m.git.buffer.attach(bufnr)
  end

  return stl.c.Future.new(function(resolve)
    era.m.git.buffer.stage_buffer(bufnr):finally(function(resolved, ok)
      if resolved and ok then
        era.m.git.buffer.refresh(bufnr):finally(function()
          resolve(true)
        end)
      else
        resolve(false)
      end
    end)
  end)
end

---@return boolean
function M.reset_buffer()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not era.m.git.buffer.is_attached(bufnr) then
    era.m.git.buffer.attach(bufnr)
  end
  return era.m.git.buffer.reset_buffer(bufnr)
end

----------------------------------------------------------------------------------------------------
-- Navigation
----------------------------------------------------------------------------------------------------

local nav_ns = vim.api.nvim_create_namespace("dot_git_hunk_nav") ---@type integer
local nav_autocmd_id = nil ---@type integer|nil
local nav_bufnr = nil ---@type integer|nil

local function clear_nav_indicator()
  if nav_bufnr and vim.api.nvim_buf_is_valid(nav_bufnr) then
    vim.api.nvim_buf_clear_namespace(nav_bufnr, nav_ns, 0, -1)
  end
  if nav_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, nav_autocmd_id)
    nav_autocmd_id = nil
  end
  nav_bufnr = nil
end

---@param bufnr                         integer
---@param lnum                          integer
---@param index                         integer
---@param total                         integer
local function show_nav_indicator(bufnr, lnum, index, total)
  clear_nav_indicator()
  nav_bufnr = bufnr

  local text = string.format("[%d/%d]", index, total) ---@type string
  pcall(vim.api.nvim_buf_set_extmark, bufnr, nav_ns, lnum - 1, 0, {
    virt_text = { { text, "m_git_hunk_indicator" } },
    virt_text_pos = "eol",
  })

  vim.schedule(function()
    nav_autocmd_id = vim.api.nvim_create_autocmd("CursorMoved", {
      buffer = bufnr,
      once = true,
      callback = function()
        clear_nav_indicator()
      end,
    })
  end)
end

function M.clear_nav()
  clear_nav_indicator()
end

---@param direction                     "next"|"prev"
---@param include_staged                boolean
local function nav_impl(direction, include_staged)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not era.m.git.buffer.is_attached(bufnr) then
    era.m.git.buffer.attach(bufnr)
    return
  end

  local unstaged = era.m.git.buffer.get_unstaged_hunks(bufnr) or {}
  local staged = include_staged and (era.m.git.buffer.get_staged_hunks(bufnr) or {}) or {}

  local hunks = {} ---@type { lnum: integer, vend: integer }[]
  for _, hunk in ipairs(unstaged) do
    local start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    hunks[#hunks + 1] = { lnum = start, vend = hunk.vend == 0 and 1 or hunk.vend }
  end
  for _, hunk in ipairs(staged) do
    local start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    hunks[#hunks + 1] = { lnum = start, vend = hunk.vend == 0 and 1 or hunk.vend }
  end

  if #hunks == 0 then
    return
  end

  table.sort(hunks, function(a, b)
    return a.lnum < b.lnum
  end)

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
  local target_idx = nil ---@type integer|nil

  if direction == "next" then
    for i, h in ipairs(hunks) do
      if h.lnum > lnum then
        target_idx = i
        break
      end
    end
    target_idx = target_idx or 1
  else
    for i = #hunks, 1, -1 do
      if hunks[i].vend < lnum then
        target_idx = i
        break
      end
    end
    target_idx = target_idx or #hunks
  end

  local target = hunks[target_idx]
  vim.api.nvim_win_set_cursor(winnr, { target.lnum, 0 })
  show_nav_indicator(bufnr, target.lnum, target_idx, #hunks)
end

---@param direction                     "next"|"prev"
function M.nav(direction)
  nav_impl(direction, false)
end

---@param direction                     "next"|"prev"
function M.nav_all(direction)
  nav_impl(direction, true)
end

----------------------------------------------------------------------------------------------------
-- Preview
----------------------------------------------------------------------------------------------------

---@type era.m.git.Hunkview|nil
local hunk_board = nil

function M.preview()
  if hunk_board and hunk_board:isvisible() then
    hunk_board:close()
    return
  end

  if hunk_board then
    hunk_board:dispose()
  end

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  hunk_board = era.m.git.Hunkview.new({ bufnr = bufnr })
  hunk_board:open()
end

----------------------------------------------------------------------------------------------------

return M
