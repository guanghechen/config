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

---@return table[]                     mini.ai regions for unstaged hunks
function M.ai_textobject()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local hunks = buffer_hunks[bufnr]
  if not hunks then
    return {}
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  local regions = {} ---@type table[]
  for _, hunk in ipairs(hunks) do
    local start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    local vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
    start = math.min(math.max(start, 1), line_count)
    vend = math.min(math.max(vend, start), line_count)

    local last_line = vim.api.nvim_buf_get_lines(bufnr, vend - 1, vend, true)[1] or "" ---@type string
    regions[#regions + 1] = {
      from = { line = start, col = 1 },
      to = { line = vend, col = math.max(#last_line, 1) },
      vis_mode = "V",
    }
  end
  return regions
end

----------------------------------------------------------------------------------------------------
-- Sign calculation
----------------------------------------------------------------------------------------------------

---@param hunk                          era.m.git.Hunk
---@param min_lnum                      integer|nil
---@param max_lnum                      integer|nil
---@return era.m.git.Sign[]
function M.calc_signs(hunk, min_lnum, max_lnum)
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
    local has_extra_removes = is_change_hunk and removed_count > count

    for i = 0, count - 1 do
      local lnum = start + i ---@type integer
      if lnum >= min_lnum and lnum <= max_lnum then
        local is_last_line = (i == count - 1) ---@type boolean

        if is_last_line and is_change_hunk and has_extra_removes then
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

  for _, hunk in ipairs(hunks) do
    local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
    if effective_start > max_lnum then
      break
    end

    local hunk_signs = M.calc_signs(hunk, min_lnum, max_lnum)
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
