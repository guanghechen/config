---@class dot.module.git.hunk
local M = {}

---@type table<integer, ark.c.Observable>
local buffer_hunks_observables = {}

---@type table<integer, dot.module.git.Hunk[]|nil>
local buffer_hunks = {}

---@param bufnr                      integer
---@return ark.c.Observable
function M.get_observable(bufnr)
  if not buffer_hunks_observables[bufnr] then
    buffer_hunks_observables[bufnr] = ark.c.Observable.from_value({})
  end
  return buffer_hunks_observables[bufnr]
end

---@param bufnr                      integer
---@return dot.module.git.Hunk[]|nil
function M.get(bufnr)
  return buffer_hunks[bufnr]
end

---@param bufnr                      integer
---@param hunks                      dot.module.git.Hunk[]|nil
function M.set(bufnr, hunks)
  buffer_hunks[bufnr] = hunks

  local observable = buffer_hunks_observables[bufnr]
  if observable then
    observable:next(hunks or {})
  end
end

---@param bufnr                      integer
function M.remove(bufnr)
  buffer_hunks[bufnr] = nil

  local observable = buffer_hunks_observables[bufnr]
  if observable then
    observable:next({})
    observable:dispose()
    buffer_hunks_observables[bufnr] = nil
  end
end

---@param bufnr                      integer
---@return dot.module.git.HunkSummary
function M.get_summary(bufnr)
  return M.summary(buffer_hunks[bufnr])
end

---@param lnum                       integer
---@param hunks                      dot.module.git.Hunk[]|nil
---@return dot.module.git.Hunk|nil
---@return integer|nil
function M.find(lnum, hunks)
  if not hunks then
    return nil, nil
  end
  for i, hunk in ipairs(hunks) do
    -- For topdelete (added.start = 0, vend = 0), match when lnum = 1
    local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
    if lnum >= effective_start and lnum <= effective_vend then
      return hunk, i
    end
  end
  return nil, nil
end

---@param lnum                       integer
---@param hunks                      dot.module.git.Hunk[]|nil
---@param direction                  "next"|"prev"|"first"|"last"
---@param opts                       { wrap: boolean|nil, navigation_message: boolean|nil }|nil
---@return dot.module.git.Hunk|nil
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
      -- For topdelete (added.start = 0), use effective position 1
      local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
      if effective_start > lnum then
        return hunk, i
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
      -- For topdelete (vend = 0), use effective position 1
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

---@param hunks                      dot.module.git.Hunk[]|nil
---@return dot.module.git.HunkSummary
function M.summary(hunks)
  local added = 0
  local changed = 0
  local removed = 0

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

---@param hunks                      dot.module.git.Hunk[]|nil
---@param top                        integer
---@param bot                        integer
---@return dot.module.git.Hunk|nil
function M.create_partial(hunks, top, bot)
  if not hunks or #hunks == 0 then
    return nil
  end

  local dominated_hunks = {} ---@type dot.module.git.Hunk[]

  for _, hunk in ipairs(hunks) do
    -- For topdelete (added.start = 0, vend = 0), use effective position 1
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

  local removed_start = first_hunk.removed.start
  local removed_count = 0
  local first_effective_start = first_hunk.added.start == 0 and 1 or first_hunk.added.start ---@type integer
  local added_start = math.max(first_effective_start, top)
  local added_count = 0

  local removed_lines = {} ---@type string[]
  local added_lines = {} ---@type string[]

  for _, hunk in ipairs(dominated_hunks) do
    local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
    local hunk_top = math.max(effective_start, top)
    local hunk_bot = math.min(effective_vend, bot)

    if hunk.type == "delete" then
      for _, line in ipairs(hunk.removed.lines) do
        removed_lines[#removed_lines + 1] = line
      end
      removed_count = removed_count + hunk.removed.count
    elseif hunk.type == "add" then
      local offset = hunk_top - hunk.added.start
      local count = hunk_bot - hunk_top + 1
      for i = offset + 1, offset + count do
        added_lines[#added_lines + 1] = hunk.added.lines[i]
      end
      added_count = added_count + count
    else
      local add_offset = hunk_top - hunk.added.start
      local add_count = hunk_bot - hunk_top + 1

      local ratio = hunk.removed.count / hunk.added.count
      local remove_offset = math.floor(add_offset * ratio)
      local remove_count = math.ceil(add_count * ratio)

      if add_offset == 0 and add_count == hunk.added.count then
        remove_offset = 0
        remove_count = hunk.removed.count
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
    end
  end

  local hunk_type ---@type dot.module.git.HunkType
  if removed_count == 0 then
    hunk_type = "add"
  elseif added_count == 0 then
    hunk_type = "delete"
  else
    hunk_type = "change"
  end

  ---@type dot.module.git.Hunk
  return {
    type = hunk_type,
    head = string.format("@@ -%d,%d +%d,%d @@", removed_start, removed_count, added_start, added_count),
    added = {
      start = added_start,
      count = added_count,
      lines = added_lines,
    },
    removed = {
      start = removed_start,
      count = removed_count,
      lines = removed_lines,
    },
    vend = added_start + math.max(added_count, 1) - 1,
  }
end

---@param relpath                    string
---@param hunk                       dot.module.git.Hunk
---@param mode_bits                  string|nil
---@param invert                     boolean|nil
---@return string
function M.create_patch(relpath, hunk, mode_bits, invert)
  local lines = {} ---@type string[]
  invert = invert or false
  mode_bits = mode_bits or "100644"

  lines[#lines + 1] = string.format("diff --git a/%s b/%s", relpath, relpath)
  lines[#lines + 1] = string.format("index 000000..000000 %s", mode_bits)
  lines[#lines + 1] = string.format("--- a/%s", relpath)
  lines[#lines + 1] = string.format("+++ b/%s", relpath)

  local removed_start = hunk.removed.start
  local removed_count = hunk.removed.count
  local added_start = hunk.added.start
  local added_count = hunk.added.count

  if invert then
    removed_start, added_start = added_start, removed_start
    removed_count, added_count = added_count, removed_count
  end

  lines[#lines + 1] = string.format("@@ -%d,%d +%d,%d @@", removed_start, removed_count, added_start, added_count)

  local removed_lines = invert and hunk.added.lines or hunk.removed.lines
  local added_lines = invert and hunk.removed.lines or hunk.added.lines

  for _, line in ipairs(removed_lines) do
    lines[#lines + 1] = "-" .. line
  end

  for _, line in ipairs(added_lines) do
    lines[#lines + 1] = "+" .. line
  end

  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end

---@param hunk                       dot.module.git.Hunk
---@param min_lnum                   integer|nil
---@param max_lnum                   integer|nil
---@return dot.module.git.Sign[]
function M.calc_signs(hunk, min_lnum, max_lnum)
  local signs = {} ---@type dot.module.git.Sign[]
  min_lnum = min_lnum or 1
  max_lnum = max_lnum or math.huge

  local start = hunk.added.start
  local count = hunk.added.count
  local removed_count = hunk.removed.count

  if count == 0 then
    -- Pure deletion: show sign at effective position
    if start == 0 then
      -- Topdelete: deletion at file start, show at line 1
      if 1 >= min_lnum and 1 <= max_lnum then
        signs[#signs + 1] = { type = "topdelete", lnum = 1, count = removed_count }
      end
    else
      -- Normal delete: show at the line where deletion occurred
      if start >= min_lnum and start <= max_lnum then
        signs[#signs + 1] = { type = "delete", lnum = start, count = removed_count }
      end
    end
  else
    for i = 0, count - 1 do
      local lnum = start + i
      if lnum >= min_lnum and lnum <= max_lnum then
        if i == 0 and removed_count > 0 then
          if count > removed_count then
            signs[#signs + 1] = { type = "changedelete", lnum = lnum }
          else
            signs[#signs + 1] = { type = "change", lnum = lnum }
          end
        elseif removed_count > 0 and i < removed_count then
          signs[#signs + 1] = { type = "change", lnum = lnum }
        else
          signs[#signs + 1] = { type = "add", lnum = lnum }
        end
      end
    end
  end

  return signs
end

---@param hunks                      dot.module.git.Hunk[]|nil
---@param min_lnum                   integer|nil
---@param max_lnum                   integer|nil
---@return dot.module.git.Sign[]
function M.calc_signs_all(hunks, min_lnum, max_lnum)
  local signs = {} ---@type dot.module.git.Sign[]
  if not hunks then
    return signs
  end

  for _, hunk in ipairs(hunks) do
    local hunk_signs = M.calc_signs(hunk, min_lnum, max_lnum)
    for _, sign in ipairs(hunk_signs) do
      signs[#signs + 1] = sign
    end
  end

  return signs
end

---@param range                      { [1]: integer, [2]: integer }|nil
---@param callback                   fun(ok: boolean, err: string|nil)|nil
function M.stage(range, callback)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not dot.git.buffer.is_attached(bufnr) then
    dot.git.buffer.attach(bufnr)
  end
  dot.git.buffer.stage_hunk(bufnr, range, callback)
end

---@param range                      { [1]: integer, [2]: integer }|nil
---@param callback                   fun(ok: boolean, err: string|nil)|nil
function M.unstage(range, callback)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not dot.git.buffer.is_attached(bufnr) then
    dot.git.buffer.attach(bufnr)
  end
  dot.git.buffer.unstage_hunk(bufnr, range, callback)
end

---@param range                      { [1]: integer, [2]: integer }|nil
---@return boolean
---@return string|nil
function M.reset(range)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not dot.git.buffer.is_attached(bufnr) then
    dot.git.buffer.attach(bufnr)
  end
  return dot.git.buffer.reset_hunk(bufnr, range)
end

---@param callback                   fun(ok: boolean)|nil
function M.stage_buffer(callback)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not dot.git.buffer.is_attached(bufnr) then
    dot.git.buffer.attach(bufnr)
  end
  dot.git.buffer.stage_buffer(bufnr, function(ok)
    if ok then
      dot.git.buffer.refresh(bufnr, nil, function()
        if callback then
          callback(ok)
        end
      end)
    else
      if callback then
        callback(ok)
      end
    end
  end)
end

---@return boolean
function M.reset_buffer()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not dot.git.buffer.is_attached(bufnr) then
    dot.git.buffer.attach(bufnr)
  end
  return dot.git.buffer.reset_buffer(bufnr)
end

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

---@param bufnr                      integer
---@param lnum                       integer
---@param index                      integer
---@param total                      integer
local function show_nav_indicator(bufnr, lnum, index, total)
  clear_nav_indicator()
  nav_bufnr = bufnr

  local text = string.format("[%d/%d]", index, total) ---@type string
  pcall(vim.api.nvim_buf_set_extmark, bufnr, nav_ns, lnum - 1, 0, {
    virt_text = { { text, "fg_hunk_indicator" } },
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

---@param direction                  "next"|"prev"
---@param include_staged             boolean
local function nav_impl(direction, include_staged)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not dot.git.buffer.is_attached(bufnr) then
    dot.git.buffer.attach(bufnr)
    return
  end

  local unstaged = dot.git.buffer.get_unstaged_hunks(bufnr) or {}
  local staged = include_staged and (dot.git.buffer.get_staged_hunks(bufnr) or {}) or {}

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

---@param direction                  "next"|"prev"
function M.nav(direction)
  nav_impl(direction, false)
end

---@param direction                  "next"|"prev"
function M.nav_all(direction)
  nav_impl(direction, true)
end

---@type dot.module.board.GitHunk|nil
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
  hunk_board = dot.board.GitHunk.new({ bufnr = bufnr })
  hunk_board:open()
end

function M.setup() end

return M
