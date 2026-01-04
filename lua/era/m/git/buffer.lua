local DEBOUNCE_MS = 200 ---@type integer

---@class era.m.git.buffer
local M = {}

---@type table<integer, era.m.git.buffer.ICache>
local cache = {}

---@type era.m.git.Repo|nil
local repo = nil

----------------------------------------------------------------------------------------------------
-- Update lock mechanism
-- Prevents concurrent updates to the same buffer and queues pending updates
----------------------------------------------------------------------------------------------------

---@class era.m.git.buffer.IUpdateLock
---@field public running              boolean
---@field public scheduled            boolean
---@field public pending_callback     (fun(): nil)|nil

---@type table<integer, era.m.git.buffer.IUpdateLock>
local update_locks = {}

---@param bufnr                         integer
---@return era.m.git.buffer.IUpdateLock
local function get_update_lock(bufnr)
  if not update_locks[bufnr] then
    update_locks[bufnr] = {
      running = false,
      scheduled = false,
      pending_callback = nil,
    }
  end
  return update_locks[bufnr]
end

---@param bufnr                         integer
local function clear_update_lock(bufnr)
  update_locks[bufnr] = nil
end

---@param bufnr                      integer
---@return boolean
local function is_buf_visible(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local winnrs = vim.fn.win_findbuf(bufnr) ---@type integer[]
  return #winnrs > 0
end

---@class era.m.git.buffer.IBatchInvalidateOpts
---@field public clear_compare_text     boolean|nil
---@field public clear_compare_text_index boolean|nil
---@field public clear_object_name      boolean|nil
---@field public delay_interval         integer

---@param opts                          era.m.git.buffer.IBatchInvalidateOpts
local function batch_invalidate_and_refresh(opts)
  local visible_buffers = {} ---@type integer[]

  for bufnr, buf_cache in pairs(cache) do
    if buf_cache then
      if opts.clear_compare_text then
        buf_cache.compare_text = nil
      end
      if opts.clear_compare_text_index then
        buf_cache.compare_text_index = nil
      end
      if opts.clear_object_name then
        buf_cache.object_name = nil
      end
      buf_cache.dirty = true
      buf_cache.force_next_update = true
      if is_buf_visible(bufnr) then
        visible_buffers[#visible_buffers + 1] = bufnr
      end
    end
  end

  for index, bufnr in ipairs(visible_buffers) do
    stl.timer.delay(function()
      if cache[bufnr] then
        M.refresh(bufnr, true)
      end
    end, index * opts.delay_interval)
  end
end

---@param bufnr                      integer
---@return string[]
local function get_buf_lines(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  -- Append empty string if buffer has EOL (trailing newline)
  -- This matches the format from git cat-file: "line1\nline2\n" -> {"line1", "line2", ""}
  -- nvim_buf_get_lines doesn't include trailing newline info, so we check vim.bo.eol
  if vim.bo[bufnr].eol and #lines > 0 then
    lines[#lines + 1] = ""
  end
  return lines
end

---@param buf_cache                  era.m.git.buffer.ICache
---@param callback                   (fun(): nil)|nil
local function update_hunks(buf_cache, callback)
  local bufnr = buf_cache.bufnr ---@type integer

  if not vim.api.nvim_buf_is_valid(bufnr) then
    if callback then
      callback()
    end
    return
  end

  local lock = get_update_lock(bufnr)

  -- If already scheduled, just update the callback
  if lock.scheduled then
    lock.pending_callback = callback
    return
  end

  -- If running, schedule for later execution
  if lock.running then
    lock.scheduled = true
    lock.pending_callback = callback
    return
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  if tick == buf_cache.changedtick and not buf_cache.force_next_update then
    if callback then
      callback()
    end
    return
  end

  lock.running = true
  buf_cache.changedtick = tick
  local should_force_update = buf_cache.force_next_update ---@type boolean
  buf_cache.force_next_update = false

  local old_hunks = buf_cache.hunks ---@type era.m.git.Hunk[]|nil
  local old_hunks_staged = buf_cache.hunks_staged ---@type era.m.git.Hunk[]|nil

  local buf_lines = get_buf_lines(bufnr) ---@type string[]
  local toplevel = buf_cache.repo.toplevel ---@type string
  local relpath = buf_cache.relpath ---@type string

  local function finish()
    if not vim.api.nvim_buf_is_valid(bufnr) or not cache[bufnr] then
      lock.running = false
      lock.scheduled = false
      lock.pending_callback = nil
      if callback then
        callback()
      end
      return
    end

    buf_cache.untracked = buf_cache.object_name == nil and #(buf_cache.compare_text or {}) == 0

    local compare_text_index = buf_cache.compare_text_index or {}
    local compare_text_head = buf_cache.compare_text or {}

    buf_cache.hunks = era.m.git.diff.run_diff(compare_text_index, buf_lines)

    if compare_text_index == compare_text_head then
      buf_cache.hunks_staged = nil
    else
      local hunks_head = era.m.git.diff.run_diff(compare_text_head, buf_lines)
      buf_cache.hunks_staged = era.m.git.diff.filter_common(hunks_head, buf_cache.hunks)
    end

    era.m.git.hunk.set(bufnr, buf_cache.hunks)

    local hunks_changed = era.m.git.hunk.compare_heads(buf_cache.hunks, old_hunks) ---@type boolean
    local hunks_staged_changed = era.m.git.hunk.compare_heads(buf_cache.hunks_staged, old_hunks_staged) ---@type boolean

    if should_force_update or hunks_changed or hunks_staged_changed then
      era.m.git.sign.update(bufnr, buf_cache.hunks, buf_cache.hunks_staged, {
        untracked = buf_cache.untracked,
        force = should_force_update,
      })
    end

    buf_cache.dirty = false

    -- Complete current update
    lock.running = false
    if callback then
      callback()
    end

    -- Check if there's a scheduled update waiting
    if lock.scheduled then
      lock.scheduled = false
      local pending_cb = lock.pending_callback
      lock.pending_callback = nil
      -- Use vim.schedule to avoid deep recursion
      vim.schedule(function()
        local current_cache = cache[bufnr]
        if current_cache and current_cache.attached then
          update_hunks(current_cache, pending_cb)
        elseif pending_cb then
          pending_cb()
        end
      end)
    end
  end

  local need_head = not buf_cache.compare_text ---@type boolean
  local need_index = not buf_cache.compare_text_index ---@type boolean
  local object_name = buf_cache.object_name ---@type string|nil

  if not need_head and not need_index then
    finish()
    return
  end

  if need_index and not object_name then
    need_index = false
  end

  local pending = 0 ---@type integer
  if need_head then
    pending = pending + 1
  end
  if need_index then
    pending = pending + 1
  end

  if pending == 0 then
    if not buf_cache.compare_text_index then
      buf_cache.compare_text_index = buf_cache.compare_text or {}
    end
    finish()
    return
  end

  local function maybe_finish()
    pending = pending - 1
    if pending == 0 then
      if not buf_cache.compare_text_index then
        buf_cache.compare_text_index = buf_cache.compare_text or {}
      end
      finish()
    end
  end

  if need_head then
    era.m.git.cmd.get_show_text_async(toplevel, "HEAD:" .. relpath, function(lines)
      buf_cache.compare_text = lines or {}
      maybe_finish()
    end)
  end

  if need_index then
    era.m.git.cmd.get_show_text_async(toplevel, object_name --[[@as string]], function(lines)
      buf_cache.compare_text_index = lines or buf_cache.compare_text
      maybe_finish()
    end)
  end
end

---@param bufnr                      integer
---@param opts                       { force: boolean|nil }|nil
---@return boolean
function M.attach(bufnr, opts)
  opts = opts or {}

  if cache[bufnr] and not opts.force then
    return true
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.bo[bufnr].buftype ~= "" then
    return false
  end

  local file = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if file == "" then
    return false
  end

  file = dot.path.normalize(file)

  if not yoz.path.is_exist(file) then
    return false
  end

  if not dot.path.is_git_repo() then
    return false
  end

  local function do_attach(r)
    if not r then
      return
    end

    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local relpath = r:get_relpath(file)

    ---@type era.m.git.buffer.ICache
    local buf_cache = {
      attached = true,
      bufnr = bufnr,
      changedtick = -1,
      compare_text = nil,
      compare_text_index = nil,
      dirty = false,
      file = file,
      force_next_update = true,
      hunks = nil,
      hunks_staged = nil,
      mode_bits = nil,
      object_name = nil,
      relpath = relpath,
      repo = r,
      untracked = false,
      update_debounced = nil,
    }

    buf_cache.update_debounced = stl.timer.debounce(function()
      if cache[bufnr] and buf_cache.attached then
        update_hunks(buf_cache)
      end
    end, DEBOUNCE_MS)

    cache[bufnr] = buf_cache

    local ok = vim.api.nvim_buf_attach(bufnr, false, {
      on_detach = function(_, buf)
        M.detach(buf)
      end,
      on_lines = function(_, buf, _, first, last_orig, last_new)
        local bc = cache[buf]
        if not bc then
          return
        end

        era.m.git.sign.on_lines(buf, last_orig, last_new)

        -- Check if the modified range intersects with existing signs
        -- first is 0-indexed, convert to 1-indexed for sign checking
        -- Use max(last_orig, last_new) to cover both insertion and deletion cases
        local check_start = first + 1 ---@type integer
        local check_end = math.max(last_orig, last_new) ---@type integer
        if bc.hunks and era.m.git.sign.contains_range(buf, check_start, check_end) then
          bc.force_next_update = true
        elseif bc.hunks_staged and era.m.git.sign.contains_range(buf, check_start, check_end) then
          bc.force_next_update = true
        end

        if is_buf_visible(buf) and bc.update_debounced then
          bc.update_debounced()
        else
          bc.dirty = true
        end
      end,
      on_reload = function(_, buf)
        local bc = cache[buf]
        if not bc then
          return
        end
        bc.force_next_update = true
        if is_buf_visible(buf) and bc.update_debounced then
          bc.update_debounced()
        else
          bc.dirty = true
        end
      end,
    })

    if not ok then
      stl.reporter.warn({
        from = "era.m.git.buffer",
        subject = "attach",
        message = "Failed to attach buffer",
        details = { bufnr = bufnr, file = file },
      })
      M.detach(bufnr)
      return
    end

    era.m.git.cmd.get_file_info_async(r.toplevel, relpath, function(file_info)
      if not cache[bufnr] then
        return
      end
      buf_cache.mode_bits = file_info and file_info.mode_bits
      buf_cache.object_name = file_info and file_info.object_name
      update_hunks(buf_cache)
    end)
  end

  if repo then
    do_attach(repo)
    return true
  end

  local toplevel = dot.path.workspace() ---@type string
  era.m.git.repo.new(toplevel, function(r)
    if r then
      repo = r
      era.m.git.state.o_branch:next(r.abbrev_head)
      era.m.git.watcher.update(r.gitdir)
    end
    do_attach(r)
  end)

  return true
end

---@param bufnr                      integer
function M.detach(bufnr)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    return
  end

  buf_cache.attached = false
  clear_update_lock(bufnr)

  if buf_cache.update_debounced then
    buf_cache.update_debounced:dispose()
  end

  era.m.git.sign.clear(bufnr)
  era.m.git.hunk.remove(bufnr)

  cache[bufnr] = nil
end

---@param bufnr                      integer
---@return era.m.git.buffer.ICache|nil
function M.get_cache(bufnr)
  return cache[bufnr]
end

---@param bufnr                      integer
---@param lnum                       integer
---@return era.m.git.Hunk|nil
---@return integer|nil
function M.get_hunk_at(bufnr, lnum)
  local buf_cache = cache[bufnr]
  if not buf_cache or not buf_cache.hunks then
    return nil, nil
  end
  return era.m.git.hunk.find(lnum, buf_cache.hunks)
end

---@return era.m.git.Repo|nil
function M.get_repo()
  return repo
end

---@param bufnr                      integer
---@return era.m.git.Hunk[]|nil
function M.get_staged_hunks(bufnr)
  local buf_cache = cache[bufnr]
  return buf_cache and buf_cache.hunks_staged
end

---@param bufnr                      integer
---@return era.m.git.Hunk[]|nil
function M.get_unstaged_hunks(bufnr)
  local buf_cache = cache[bufnr]
  return buf_cache and buf_cache.hunks
end

---@param bufnr                      integer
---@return boolean
function M.is_dirty(bufnr)
  local buf_cache = cache[bufnr]
  return buf_cache ~= nil and buf_cache.dirty == true
end

---@param bufnr                      integer
---@return boolean
function M.is_attached(bufnr)
  local buf_cache = cache[bufnr]
  return buf_cache ~= nil and buf_cache.attached
end

function M.invalidate_compare_text_all()
  batch_invalidate_and_refresh({
    clear_compare_text = true,
    clear_compare_text_index = true,
    clear_object_name = true,
    delay_interval = 15,
  })
end

function M.invalidate_index_all()
  batch_invalidate_and_refresh({
    clear_compare_text_index = true,
    clear_object_name = true,
    delay_interval = 20,
  })
end

function M.mark_dirty_all()
  batch_invalidate_and_refresh({
    clear_compare_text_index = true,
    clear_object_name = true,
    delay_interval = 10,
  })
end

---@param bufnr                      integer
---@param invalidate_compare_text    boolean|nil
---@param callback                   (fun(): nil)|nil
function M.refresh(bufnr, invalidate_compare_text, callback)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    if callback then
      callback()
    end
    return
  end

  if invalidate_compare_text then
    era.m.git.cmd.get_file_info_async(buf_cache.repo.toplevel, buf_cache.relpath, function(file_info)
      if not cache[bufnr] then
        if callback then
          callback()
        end
        return
      end

      local new_object_name = file_info and file_info.object_name
      local old_object_name = buf_cache.object_name

      if new_object_name ~= old_object_name then
        buf_cache.compare_text_index = nil
      end

      buf_cache.mode_bits = file_info and file_info.mode_bits
      buf_cache.object_name = new_object_name
      buf_cache.force_next_update = true

      update_hunks(buf_cache, callback)
    end)
  else
    buf_cache.force_next_update = true
    update_hunks(buf_cache, callback)
  end
end

---@param bufnr                      integer
---@return boolean
function M.reset_buffer(bufnr)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    return false
  end

  local compare_text = buf_cache.compare_text or {} ---@type string[]
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, compare_text)
  return true
end

---@param bufnr                      integer
---@param range                      { [1]: integer, [2]: integer }|nil
---@return boolean
---@return string|nil
function M.reset_hunk(bufnr, range)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    return false, "Buffer not attached"
  end

  local hunks ---@type era.m.git.Hunk[]
  if range then
    hunks = era.m.git.hunk.create_partials(buf_cache.hunks, range[1], range[2])
  else
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
    local hunk = era.m.git.hunk.find(lnum, buf_cache.hunks)
    hunks = hunk and { hunk } or {}
  end

  if #hunks == 0 then
    return false, "No hunk at cursor"
  end

  -- Process hunks from bottom to top to avoid line number offset issues
  for i = #hunks, 1, -1 do
    local hunk = hunks[i] ---@type era.m.git.Hunk
    -- For topdelete (added.start = 0), insert at beginning (index 0)
    local start_line = hunk.added.start == 0 and 0 or (hunk.added.start - 1) ---@type integer
    local end_line = start_line + hunk.added.count ---@type integer
    vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, hunk.removed.lines)
  end

  return true, nil
end

---@param bufnr                      integer
---@param callback                   fun(ok: boolean)|nil
function M.stage_buffer(bufnr, callback)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    if callback then
      callback(false)
    end
    return
  end

  local relpath = buf_cache.relpath
  era.m.git.cmd.stage_file_async(buf_cache.repo.toplevel, relpath, function(ok)
    if callback then
      callback(ok)
    end
  end)
end

---@param bufnr                      integer
---@param range                      { [1]: integer, [2]: integer }|nil
---@param callback                   fun(ok: boolean, err: string|nil)|nil
function M.stage_hunk(bufnr, range, callback)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    if callback then
      callback(false, "Buffer not attached")
    end
    return
  end

  local hunks ---@type era.m.git.Hunk[]
  if range then
    hunks = era.m.git.hunk.create_partials(buf_cache.hunks, range[1], range[2])
  else
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
    local hunk = era.m.git.hunk.find(lnum, buf_cache.hunks)
    hunks = hunk and { hunk } or {}
  end

  if #hunks == 0 then
    if callback then
      callback(false, "No hunk at cursor")
    end
    return
  end

  local toplevel = buf_cache.repo.toplevel
  local relpath = buf_cache.relpath
  local mode_bits = buf_cache.mode_bits

  local function do_stage()
    local patch = era.m.git.hunk.create_patch_multi(relpath, hunks, mode_bits, false)
    era.m.git.cmd.apply_patch_async(toplevel, patch, false, function(ok, err)
      if ok then
        M.refresh(bufnr, true, function()
          if callback then
            callback(true, nil)
          end
        end)
      else
        if callback then
          callback(false, err)
        end
      end
    end)
  end

  if not buf_cache.object_name then
    era.m.git.cmd.add_intent_to_add_async(toplevel, relpath, function()
      era.m.git.cmd.get_file_info_async(toplevel, relpath, function(file_info)
        buf_cache.mode_bits = file_info and file_info.mode_bits
        buf_cache.object_name = file_info and file_info.object_name
        mode_bits = buf_cache.mode_bits
        if not buf_cache.object_name or not buf_cache.mode_bits then
          if callback then
            callback(false, "Failed to read index entry for new file")
          end
          return
        end
        do_stage()
      end)
    end)
  else
    do_stage()
  end
end

--- Apply inverted hunks to restore index content to HEAD state.
---
--- This function takes the current index content and "undoes" the staged changes
--- by replacing the modified sections with their original HEAD content.
---
--- Coordinate system:
--- - hunks_staged are computed as: diff(HEAD, Index)
---   - hunk.removed = lines from HEAD (what was removed to get Index)
---   - hunk.added = lines in Index (what was added to get Index)
--- - To unstage: replace added sections in Index with removed sections from HEAD
---
--- Edge cases handled:
--- - Pure deletions (added.count == 0): added.start points to where deletion occurred
--- - Pure additions (removed.count == 0): just remove the added lines
--- - Hunks must be sorted by added.start for correct application
---
---@param index_lines                string[]  Current index (staged) content
---@param head_lines                 string[]  Original HEAD content
---@param hunks                      era.m.git.Hunk[]  Staged hunks (HEAD vs Index diff)
---@return string[]
local function apply_inverted_hunks(index_lines, head_lines, hunks)
  if #hunks == 0 then
    return index_lines
  end

  table.sort(hunks, function(a, b)
    return a.added.start < b.added.start
  end)

  local result = {} ---@type string[]
  local current_line = 1

  for _, hunk in ipairs(hunks) do
    local start_in_index = hunk.added.start
    local count_in_index = hunk.added.count
    local start_in_head = hunk.removed.start
    local count_in_head = hunk.removed.count

    -- For topdelete (start_in_index = 0), no lines to copy before the hunk
    -- Otherwise, copy lines from current position to just before the hunk
    if start_in_index > 0 then
      for i = current_line, start_in_index - 1 do
        result[#result + 1] = index_lines[i]
      end
    end
    -- Move past the added lines in index (for topdelete, this is 0 + 0 = 0, so use max(1, ...))
    current_line = math.max(1, start_in_index + count_in_index)

    if count_in_head > 0 then
      for i = start_in_head, start_in_head + count_in_head - 1 do
        if head_lines[i] then
          result[#result + 1] = head_lines[i]
        end
      end
    end
  end

  for i = current_line, #index_lines do
    result[#result + 1] = index_lines[i]
  end

  return result
end

---@param bufnr                      integer
---@param range                      { [1]: integer, [2]: integer }|nil
---@param callback                   fun(ok: boolean, err: string|nil)|nil
function M.unstage_hunk(bufnr, range, callback)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    if callback then
      callback(false, "Buffer not attached")
    end
    return
  end

  local hunks_staged = buf_cache.hunks_staged
  if not hunks_staged or #hunks_staged == 0 then
    if callback then
      callback(false, "No staged hunks")
    end
    return
  end

  local head_lines = buf_cache.compare_text
  local index_lines = buf_cache.compare_text_index
  if not head_lines or not index_lines then
    if callback then
      callback(false, "Missing compare text")
    end
    return
  end

  -- hunks_staged is from filter_common(diff(HEAD, Buffer), diff(Index, Buffer))
  -- Its coordinates are in Buffer line numbers, but apply_inverted_hunks needs
  -- hunks with Index coordinates. Compute diff(HEAD, Index) for correct coordinates.
  local hunks_head_to_index = era.m.git.diff.run_diff(head_lines, index_lines)

  if #hunks_head_to_index == 0 then
    if callback then
      callback(false, "No staged changes found")
    end
    return
  end

  -- User selects hunks based on Buffer line numbers (from hunks_staged).
  -- We need to find the corresponding hunks in hunks_head_to_index.
  -- Since both represent the same staged changes, we match by hunk index.
  local selected_indices = {} ---@type table<integer, boolean>

  if range then
    local top, bot = range[1], range[2] ---@type integer, integer
    for i, hunk in ipairs(hunks_staged) do
      local effective_start = hunk.added.start == 0 and 1 or hunk.added.start ---@type integer
      local effective_vend = hunk.vend == 0 and 1 or hunk.vend ---@type integer
      if not (effective_vend < top or effective_start > bot) then
        selected_indices[i] = true
      end
    end
  else
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
    local _, idx = era.m.git.hunk.find(lnum, hunks_staged)
    if idx then
      selected_indices[idx] = true
    end
  end

  if not next(selected_indices) then
    if callback then
      callback(false, "No staged hunk at cursor")
    end
    return
  end

  -- Select corresponding hunks from hunks_head_to_index
  local selected_hunks = {} ---@type era.m.git.Hunk[]
  for i, hunk in ipairs(hunks_head_to_index) do
    if selected_indices[i] then
      selected_hunks[#selected_hunks + 1] = hunk
    end
  end

  if #selected_hunks == 0 then
    if callback then
      callback(false, "Failed to map staged hunks")
    end
    return
  end

  local new_index_lines = apply_inverted_hunks(index_lines, head_lines, selected_hunks)
  local toplevel = buf_cache.repo.toplevel
  local relpath = buf_cache.relpath
  local mode_bits = buf_cache.mode_bits or "100644"

  era.m.git.cmd.hash_object_async(toplevel, relpath, new_index_lines, function(hash)
    if not hash then
      if callback then
        callback(false, "Failed to hash object")
      end
      return
    end

    era.m.git.cmd.update_index_async(toplevel, mode_bits, hash, relpath, function(ok)
      if ok then
        M.refresh(bufnr, true, function()
          if callback then
            callback(true, nil)
          end
        end)
      else
        if callback then
          callback(false, "Failed to update index")
        end
      end
    end)
  end)
end

function M.setup()
  local augroup = vim.api.nvim_create_augroup("DotModuleGitBuffer", { clear = true }) ---@type integer

  ---@type stl.timer.IDisposableCallable
  local buf_enter_debounced = stl.timer.debounce(function(bufnr)
    if M.is_dirty(bufnr) then
      M.refresh(bufnr, true)
    end
  end, 50)

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = augroup,
    callback = function(args)
      M.attach(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = function(args)
      M.refresh(args.buf, true)
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    callback = function(args)
      buf_enter_debounced(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    callback = function(args)
      M.detach(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = augroup,
    pattern = { "fileformat", "bomb", "eol" },
    callback = function(args)
      local bufnr = args.buf ---@type integer
      local buf_cache = cache[bufnr]
      if not buf_cache then
        return
      end
      buf_cache.force_next_update = true
      if buf_cache.update_debounced then
        buf_cache.update_debounced()
      end
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_is_valid(buf) then
      M.attach(buf)
    end
  end
end

return M
