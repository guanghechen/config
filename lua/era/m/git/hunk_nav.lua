---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.hunk_nav" ---@type string

local git_diff = require("era.m.git.diff")
local git_staging = require("era.m.git.staging")

---@class era.m.git.hunk_nav
local M = {}

----------------------------------------------------------------------------------------------------
-- Navigation
----------------------------------------------------------------------------------------------------

---@class era.m.git.hunk_nav.INavIndicator
---@field public bufnr                  integer
---@field public index                  integer
---@field public total                  integer
---@field public winnr                  integer

---@class era.m.git.hunk_nav.IDiffNavRange
---@field public first                  integer
---@field public index                  integer
---@field public last                   integer

---@class era.m.git.hunk_nav.IDiffNavCache
---@field public bufnr_a                integer
---@field public bufnr_b                integer
---@field public changedtick_a          integer
---@field public changedtick_b          integer
---@field public endofline_a            boolean
---@field public endofline_b            boolean
---@field public ranges                 table<integer, era.m.git.hunk_nav.IDiffNavRange[]>
---@field public total                  integer
---@field public winnr_a                integer
---@field public winnr_b                integer

local nav_autocmd_id = nil ---@type integer|nil
local diff_nav_cache = nil ---@type era.m.git.hunk_nav.IDiffNavCache|nil
local nav_indicator = nil ---@type era.m.git.hunk_nav.INavIndicator|nil

---@param winnr                         integer
local function redraw_nav_winline(winnr)
  if vim.api.nvim_win_is_valid(winnr) then
    dot.state.status.dirty_winline_nr:next(winnr, { force = true })
  end
end

local function clear_nav_indicator()
  local winnr = nav_indicator ~= nil and nav_indicator.winnr or nil ---@type integer|nil
  if nav_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, nav_autocmd_id)
    nav_autocmd_id = nil
  end
  nav_indicator = nil
  if winnr ~= nil then
    redraw_nav_winline(winnr)
  end
end

---@param winnr                         integer
---@return integer|nil index
---@return integer|nil total
function M.get_nav_indicator(winnr)
  local indicator = nav_indicator
  if
    indicator == nil
    or indicator.winnr ~= winnr
    or not vim.api.nvim_win_is_valid(winnr)
    or vim.api.nvim_win_get_buf(winnr) ~= indicator.bufnr
  then
    return nil, nil
  end
  return indicator.index, indicator.total
end

---@param winnr                         integer
---@param bufnr                         integer
---@param index                         integer
---@param total                         integer
local function show_nav_indicator(winnr, bufnr, index, total)
  clear_nav_indicator()
  local indicator = { winnr = winnr, bufnr = bufnr, index = index, total = total }
  nav_indicator = indicator
  redraw_nav_winline(winnr)

  nav_autocmd_id = vim.api.nvim_create_autocmd({ "BufEnter", "WinClosed" }, {
    callback = function(args)
      if nav_indicator ~= indicator then
        return
      end
      if args.event == "WinClosed" and tonumber(args.match) == winnr then
        clear_nav_indicator()
        return
      end
      if not vim.api.nvim_win_is_valid(winnr) or vim.api.nvim_win_get_buf(winnr) ~= bufnr then
        clear_nav_indicator()
      end
    end,
  })
end

function M.clear_nav()
  clear_nav_indicator()
end

---@param winnr                         integer
---@return integer|nil winnr_a
---@return integer|nil winnr_b
local function get_diff_pair_winnrs(winnr)
  local diff_winnrs = {} ---@type integer[]
  for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(candidate) and vim.api.nvim_get_option_value("diff", { win = candidate }) then
      diff_winnrs[#diff_winnrs + 1] = candidate
    end
  end
  if #diff_winnrs ~= 2 or (diff_winnrs[1] ~= winnr and diff_winnrs[2] ~= winnr) then
    return nil, nil
  end

  local winnr_a = diff_winnrs[1] ---@type integer
  local winnr_b = diff_winnrs[2] ---@type integer
  local pos_a = vim.api.nvim_win_get_position(winnr_a) ---@type integer[]
  local pos_b = vim.api.nvim_win_get_position(winnr_b) ---@type integer[]
  if pos_b[2] < pos_a[2] or (pos_b[2] == pos_a[2] and pos_b[1] < pos_a[1]) then
    winnr_a, winnr_b = winnr_b, winnr_a
  end
  return winnr_a, winnr_b
end

---@return string[]
local function get_diff_buffer_lines(bufnr)
  return git_staging.from_buffer(bufnr).lines
end

---@param ranges                        era.m.git.hunk_nav.IDiffNavRange[]
---@param start                         integer
---@param count                         integer
---@param line_count                    integer
---@param index                         integer
local function append_diff_nav_range(ranges, start, count, line_count, index)
  -- A zero-count side represents an insertion after start, clamped at BOF/EOF.
  local first = count == 0 and math.min(math.max(start + 1, 1), line_count) or start ---@type integer
  ranges[#ranges + 1] = {
    first = first,
    index = index,
    last = count == 0 and first or start + count - 1,
  }
end

---@param winnr                         integer
---@return era.m.git.hunk_nav.IDiffNavCache|nil
local function get_diff_nav_cache(winnr)
  local winnr_a, winnr_b = get_diff_pair_winnrs(winnr)
  if winnr_a == nil or winnr_b == nil then
    return nil
  end

  local bufnr_a = vim.api.nvim_win_get_buf(winnr_a) ---@type integer
  local bufnr_b = vim.api.nvim_win_get_buf(winnr_b) ---@type integer
  if bufnr_a == bufnr_b then
    return nil
  end
  if not vim.api.nvim_buf_is_loaded(bufnr_a) or not vim.api.nvim_buf_is_loaded(bufnr_b) then
    return nil
  end

  local changedtick_a = vim.api.nvim_buf_get_changedtick(bufnr_a) ---@type integer
  local changedtick_b = vim.api.nvim_buf_get_changedtick(bufnr_b) ---@type integer
  local endofline_a = vim.api.nvim_get_option_value("endofline", { buf = bufnr_a }) ---@type boolean
  local endofline_b = vim.api.nvim_get_option_value("endofline", { buf = bufnr_b }) ---@type boolean
  local cache = diff_nav_cache
  if
    cache ~= nil
    and cache.winnr_a == winnr_a
    and cache.winnr_b == winnr_b
    and cache.bufnr_a == bufnr_a
    and cache.bufnr_b == bufnr_b
    and cache.changedtick_a == changedtick_a
    and cache.changedtick_b == changedtick_b
    and cache.endofline_a == endofline_a
    and cache.endofline_b == endofline_b
  then
    return cache
  end

  local lines_a = get_diff_buffer_lines(bufnr_a) ---@type string[]
  local lines_b = get_diff_buffer_lines(bufnr_b) ---@type string[]
  local hunks = git_diff.run_diff(lines_a, lines_b) ---@type era.m.git.Hunk[]
  local line_count_a = vim.api.nvim_buf_line_count(bufnr_a) ---@type integer
  local line_count_b = vim.api.nvim_buf_line_count(bufnr_b) ---@type integer
  local ranges_a = {} ---@type era.m.git.hunk_nav.IDiffNavRange[]
  local ranges_b = {} ---@type era.m.git.hunk_nav.IDiffNavRange[]
  for index, hunk in ipairs(hunks) do
    append_diff_nav_range(ranges_a, hunk.removed.start, hunk.removed.count, line_count_a, index)
    append_diff_nav_range(ranges_b, hunk.added.start, hunk.added.count, line_count_b, index)
  end

  cache = {
    bufnr_a = bufnr_a,
    bufnr_b = bufnr_b,
    changedtick_a = changedtick_a,
    changedtick_b = changedtick_b,
    endofline_a = endofline_a,
    endofline_b = endofline_b,
    ranges = { [bufnr_a] = ranges_a, [bufnr_b] = ranges_b },
    total = #hunks,
    winnr_a = winnr_a,
    winnr_b = winnr_b,
  }
  diff_nav_cache = cache
  return cache
end

---@param ranges                        era.m.git.hunk_nav.IDiffNavRange[]
---@param lnum                          integer
---@return integer|nil
local function find_diff_nav_index(ranges, lnum)
  local low = 1 ---@type integer
  local high = #ranges ---@type integer
  local candidate = nil ---@type integer|nil
  while low <= high do
    local mid = math.floor((low + high) / 2) ---@type integer
    if ranges[mid].first <= lnum then
      candidate = mid
      low = mid + 1
    else
      high = mid - 1
    end
  end
  if candidate == nil then
    return nil
  end

  local index = nil ---@type integer|nil
  for i = candidate, 1, -1 do
    local range = ranges[i] ---@type era.m.git.hunk_nav.IDiffNavRange
    if range.last < lnum then
      break
    end
    index = range.index
  end
  return index
end

---@param ranges                        era.m.git.hunk_nav.IDiffNavRange[]
---@param lnum                          integer
---@param direction                     "next"|"prev"
---@param total                         integer
---@return integer|nil
local function find_adjacent_diff_nav_index(ranges, lnum, direction, total)
  local current = find_diff_nav_index(ranges, lnum) ---@type integer|nil
  if current ~= nil then
    local adjacent = current + (direction == "next" and 1 or -1) ---@type integer
    return adjacent >= 1 and adjacent <= total and adjacent or current
  end

  if direction == "next" then
    for _, range in ipairs(ranges) do
      if range.first > lnum then
        return range.index
      end
    end
    return ranges[#ranges] and ranges[#ranges].index or nil
  else
    for i = #ranges, 1, -1 do
      local range = ranges[i] ---@type era.m.git.hunk_nav.IDiffNavRange
      if range.last < lnum then
        return range.index
      end
    end
    return ranges[1] and ranges[1].index or nil
  end
end

---@param ranges                        era.m.git.hunk_nav.IDiffNavRange[]
---@param source_lnum                   integer
---@param target_lnum                   integer
---@param direction                     "next"|"prev"
---@param total                         integer
---@return integer|nil
local function resolve_diff_nav_candidate(ranges, source_lnum, target_lnum, direction, total)
  return find_diff_nav_index(ranges, target_lnum) or find_adjacent_diff_nav_index(ranges, source_lnum, direction, total)
end

---@param ranges                        era.m.git.hunk_nav.IDiffNavRange[]
---@param lnum                          integer
---@param direction                     "next"|"prev"
---@return integer|nil
local function resolve_diff_nav_source(ranges, lnum, direction)
  local current = find_diff_nav_index(ranges, lnum) ---@type integer|nil
  if current ~= nil then
    return current
  end

  if direction == "next" then
    for i = #ranges, 1, -1 do
      local range = ranges[i] ---@type era.m.git.hunk_nav.IDiffNavRange
      if range.last < lnum then
        return range.index
      end
    end
    return ranges[1] and ranges[1].index or nil
  end

  for _, range in ipairs(ranges) do
    if range.first > lnum then
      return range.index
    end
  end
  return ranges[#ranges] and ranges[#ranges].index or nil
end

---@param cache                         era.m.git.hunk_nav.IDiffNavCache
---@param lnums                         table<integer, integer>
---@param direction                     "next"|"prev"
---@return integer|nil
---@return boolean exact
local function resolve_shared_diff_nav_source(cache, lnums, direction)
  local bufnr_a = vim.api.nvim_win_get_buf(cache.winnr_a) ---@type integer
  local bufnr_b = vim.api.nvim_win_get_buf(cache.winnr_b) ---@type integer
  local exact_a = find_diff_nav_index(cache.ranges[bufnr_a], lnums[cache.winnr_a]) ~= nil ---@type boolean
  local exact_b = find_diff_nav_index(cache.ranges[bufnr_b], lnums[cache.winnr_b]) ~= nil ---@type boolean
  local index_a = resolve_diff_nav_source(cache.ranges[bufnr_a], lnums[cache.winnr_a], direction)
  local index_b = resolve_diff_nav_source(cache.ranges[bufnr_b], lnums[cache.winnr_b], direction)
  if index_a == nil then
    return index_b, exact_a or exact_b
  end
  if index_b == nil then
    return index_a, exact_a or exact_b
  end
  return direction == "next" and math.min(index_a, index_b) or math.max(index_a, index_b), exact_a or exact_b
end

---@param cache                         era.m.git.hunk_nav.IDiffNavCache
---@param source_lnums                  table<integer, integer>
---@param target_lnums                  table<integer, integer>
---@param direction                     "next"|"prev"
---@return integer|nil
local function resolve_shared_diff_nav_target(cache, source_lnums, target_lnums, direction)
  local bufnr_a = vim.api.nvim_win_get_buf(cache.winnr_a) ---@type integer
  local bufnr_b = vim.api.nvim_win_get_buf(cache.winnr_b) ---@type integer
  local index_a = resolve_diff_nav_candidate(
    cache.ranges[bufnr_a],
    source_lnums[cache.winnr_a],
    target_lnums[cache.winnr_a],
    direction,
    cache.total
  )
  local index_b = resolve_diff_nav_candidate(
    cache.ranges[bufnr_b],
    source_lnums[cache.winnr_b],
    target_lnums[cache.winnr_b],
    direction,
    cache.total
  )
  if index_a == nil then
    return index_b
  end
  if index_b == nil then
    return index_a
  end
  return direction == "next" and math.max(index_a, index_b) or math.min(index_a, index_b)
end

---@param cache                         era.m.git.hunk_nav.IDiffNavCache
---@param winnr                         integer
---@param direction                     "next"|"prev"
---@return integer|nil
local function navigate_shared_diff(cache, winnr, direction)
  local source_lnums = { ---@type table<integer, integer>
    [cache.winnr_a] = vim.api.nvim_win_get_cursor(cache.winnr_a)[1],
    [cache.winnr_b] = vim.api.nvim_win_get_cursor(cache.winnr_b)[1],
  }
  local source_index, source_exact = resolve_shared_diff_nav_source(cache, source_lnums, direction)
  local linematch = tonumber(vim.o.diffopt:match("linematch:(%d+)")) ---@type integer|nil
  local max_motions = linematch ~= nil and linematch + 1 or 1 ---@type integer
  local motion = direction == "next" and "]c" or "[c" ---@type string

  for count = 1, max_motions do
    if count == 1 then
      vim.cmd.normal({ motion, bang = true })
    else
      vim.cmd.normal({ motion, bang = true, mods = { keepjumps = true } })
    end

    local target_lnums = { ---@type table<integer, integer>
      [cache.winnr_a] = vim.api.nvim_win_get_cursor(cache.winnr_a)[1],
      [cache.winnr_b] = vim.api.nvim_win_get_cursor(cache.winnr_b)[1],
    }
    if target_lnums[winnr] == source_lnums[winnr] then
      return source_exact and source_index or nil
    end

    local target_index = resolve_shared_diff_nav_target(cache, source_lnums, target_lnums, direction)
    if not source_exact then
      return target_index or source_index
    end
    if target_index ~= nil and target_index ~= source_index and source_index ~= nil then
      local adjacent = source_index + (direction == "next" and 1 or -1) ---@type integer
      return adjacent >= 1 and adjacent <= cache.total and adjacent or source_index
    end
    if
      target_lnums[cache.winnr_a] == source_lnums[cache.winnr_a]
      and target_lnums[cache.winnr_b] == source_lnums[cache.winnr_b]
    then
      return target_index or source_index
    end
    source_lnums = target_lnums
  end
  return source_index
end

---@param winnr                         integer
---@return integer[]
local function get_native_diff_hunk_lnums(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return {}
  end

  return vim.api.nvim_win_call(winnr, function()
    local view = vim.fn.winsaveview()
    local cursorbind = vim.api.nvim_get_option_value("cursorbind", { win = winnr, scope = "local" }) ---@type boolean
    local scrollbind = vim.api.nvim_get_option_value("scrollbind", { win = winnr, scope = "local" }) ---@type boolean
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
    local hunk_lnums = {} ---@type integer[]
    vim.api.nvim_set_option_value("cursorbind", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("scrollbind", false, { win = winnr, scope = "local" })
    local ok, err = xpcall(function()
      vim.api.nvim_win_set_cursor(winnr, { 1, 0 })
      if vim.fn.diff_hlID(1, 1) ~= 0 or vim.fn.diff_filler(1) > 0 then
        hunk_lnums[#hunk_lnums + 1] = 1
      end

      while true do
        local lnum_before = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
        vim.cmd.normal({ "]c", bang = true, mods = { keepjumps = true } })
        local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
        if lnum <= lnum_before then
          local last_lnum = hunk_lnums[#hunk_lnums] ---@type integer|nil
          local has_separate_eof_hunk = last_lnum ~= line_count
            or (vim.fn.diff_filler(line_count) > 0 and vim.fn.diff_hlID(line_count, 1) == 0)
          if vim.fn.diff_filler(line_count + 1) > 0 and has_separate_eof_hunk then
            hunk_lnums[#hunk_lnums + 1] = line_count
          end
          break
        end
        hunk_lnums[#hunk_lnums + 1] = lnum
      end
    end, debug.traceback)
    vim.fn.winrestview(view)
    vim.api.nvim_set_option_value("cursorbind", cursorbind, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("scrollbind", scrollbind, { win = winnr, scope = "local" })
    if not ok then
      error(err, 0)
    end
    return hunk_lnums
  end)
end

---@param direction                     "next"|"prev"
function M.nav_diff(direction)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if not vim.api.nvim_get_option_value("diff", { win = winnr }) then
    return
  end

  local cache = get_diff_nav_cache(winnr) ---@type era.m.git.hunk_nav.IDiffNavCache|nil
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if
    cache ~= nil
    and vim.api.nvim_get_option_value("cursorbind", { win = cache.winnr_a, scope = "local" })
    and vim.api.nvim_get_option_value("cursorbind", { win = cache.winnr_b, scope = "local" })
  then
    local index = navigate_shared_diff(cache, winnr, direction) ---@type integer|nil
    if index ~= nil then
      show_nav_indicator(winnr, bufnr, index, cache.total)
    end
    return
  end

  local source_lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
  vim.cmd.normal({ direction == "next" and "]c" or "[c", bang = true })
  local target_lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
  if cache ~= nil then
    if target_lnum == source_lnum then
      local index = find_diff_nav_index(cache.ranges[bufnr], source_lnum) ---@type integer|nil
      if index ~= nil then
        show_nav_indicator(winnr, bufnr, index, cache.total)
      end
      return
    end
    local index = resolve_diff_nav_candidate(cache.ranges[bufnr], source_lnum, target_lnum, direction, cache.total)
    if index ~= nil then
      show_nav_indicator(winnr, bufnr, index, cache.total)
    end
    return
  end

  local hunk_lnums = get_native_diff_hunk_lnums(winnr) ---@type integer[]
  for index, lnum in ipairs(hunk_lnums) do
    if lnum == target_lnum then
      show_nav_indicator(winnr, bufnr, index, #hunk_lnums)
      return
    end
  end
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
  show_nav_indicator(winnr, bufnr, target_idx, #hunks)
end

---@param direction                     "next"|"prev"
function M.nav(direction)
  nav_impl(direction, false)
end

---@param direction                     "next"|"prev"
function M.nav_all(direction)
  nav_impl(direction, true)
end

return M
