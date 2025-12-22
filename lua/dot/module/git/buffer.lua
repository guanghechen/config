local DEBOUNCE_MS = 200 ---@type integer

---@class dot.module.git.buffer
local M = {}

---@type table<integer, dot.module.git.buffer.ICache>
local cache = {}

---@type dot.module.git.Repo|nil
local repo = nil

---@type table<integer, boolean>
local updating = {}

---@param bufnr                      integer
---@return boolean
local function is_buf_visible(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local winnrs = vim.fn.win_findbuf(bufnr) ---@type integer[]
  return #winnrs > 0
end

---@param bufnr                      integer
---@return string[]
local function get_buf_lines(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

---@param buf_cache                  dot.module.git.buffer.ICache
---@param callback                   fun()|nil
local function update_hunks(buf_cache, callback)
  local bufnr = buf_cache.bufnr ---@type integer

  if not vim.api.nvim_buf_is_valid(bufnr) then
    if callback then
      callback()
    end
    return
  end

  if updating[bufnr] then
    if callback then
      callback()
    end
    return
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  if tick == buf_cache.changedtick and not buf_cache.force_next_update then
    if callback then
      callback()
    end
    return
  end

  updating[bufnr] = true
  buf_cache.changedtick = tick
  buf_cache.force_next_update = false

  local buf_lines = get_buf_lines(bufnr) ---@type string[]
  local toplevel = buf_cache.repo.toplevel ---@type string
  local relpath = buf_cache.relpath ---@type string

  local function finish()
    if not vim.api.nvim_buf_is_valid(bufnr) or not cache[bufnr] then
      updating[bufnr] = nil
      if callback then
        callback()
      end
      return
    end

    buf_cache.untracked = buf_cache.object_name == nil and #(buf_cache.compare_text or {}) == 0

    local compare_text_index = buf_cache.compare_text_index or {}
    local compare_text_head = buf_cache.compare_text or {}

    buf_cache.hunks = dot.git.diff.run_diff(compare_text_index, buf_lines)
    local hunks_head = dot.git.diff.run_diff(compare_text_head, buf_lines)
    buf_cache.hunks_staged = dot.git.diff.filter_common(hunks_head, buf_cache.hunks)

    dot.git.hunk.set(bufnr, buf_cache.hunks)
    dot.git.sign.update(bufnr, buf_cache.hunks, buf_cache.hunks_staged, { untracked = buf_cache.untracked })

    buf_cache.dirty = false
    updating[bufnr] = nil
    if callback then
      callback()
    end
  end

  local function fetch_index_text()
    if buf_cache.compare_text_index then
      finish()
      return
    end

    local object_name = buf_cache.object_name
    if object_name then
      dot.git.cmd.get_show_text_async(toplevel, object_name, function(lines)
        buf_cache.compare_text_index = lines or buf_cache.compare_text
        finish()
      end)
    else
      buf_cache.compare_text_index = buf_cache.compare_text
      finish()
    end
  end

  if buf_cache.compare_text then
    fetch_index_text()
  else
    dot.git.cmd.get_show_text_async(toplevel, "HEAD:" .. relpath, function(lines)
      buf_cache.compare_text = lines or {}
      fetch_index_text()
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

    ---@type dot.module.git.buffer.ICache
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

    buf_cache.update_debounced = ark.timer.debounce(function()
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

        dot.git.sign.on_lines(buf, last_orig, last_new)

        if bc.hunks and dot.git.sign.contains_range(buf, first + 1, last_new) then
          bc.force_next_update = true
        end

        if bc.update_debounced then
          bc.update_debounced()
        end
      end,
      on_reload = function(_, buf)
        local bc = cache[buf]
        if not bc then
          return
        end
        bc.force_next_update = true
        if bc.update_debounced then
          bc.update_debounced()
        end
      end,
    })

    if not ok then
      M.detach(bufnr)
      return
    end

    dot.git.cmd.get_file_info_async(r.toplevel, relpath, function(file_info)
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
  dot.git.repo.new(toplevel, function(r)
    if r then
      repo = r
      dot.git.state.o_branch:next(r.abbrev_head)
      dot.git.watcher.update(r.gitdir)
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
  updating[bufnr] = nil

  if buf_cache.update_debounced then
    buf_cache.update_debounced:dispose()
  end

  dot.git.sign.clear(bufnr)
  dot.git.hunk.remove(bufnr)

  cache[bufnr] = nil
end

---@param bufnr                      integer
---@return dot.module.git.buffer.ICache|nil
function M.get_cache(bufnr)
  return cache[bufnr]
end

---@param bufnr                      integer
---@param lnum                       integer
---@return dot.module.git.Hunk|nil
---@return integer|nil
function M.get_hunk_at(bufnr, lnum)
  local buf_cache = cache[bufnr]
  if not buf_cache or not buf_cache.hunks then
    return nil, nil
  end
  return dot.git.hunk.find(lnum, buf_cache.hunks)
end

---@param bufnr                      integer
---@return dot.module.git.Hunk[]|nil
function M.get_hunks(bufnr)
  local buf_cache = cache[bufnr]
  return buf_cache and buf_cache.hunks
end

---@return dot.module.git.Repo|nil
function M.get_repo()
  return repo
end

---@param bufnr                      integer
---@return dot.module.git.Hunk[]|nil
function M.get_staged_hunks(bufnr)
  local buf_cache = cache[bufnr]
  return buf_cache and buf_cache.hunks_staged
end

---@param bufnr                      integer
---@return dot.module.git.Hunk[]|nil
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

---@param bufnr                      integer
---@param invalidate_compare_text    boolean|nil
---@param callback                   fun()|nil
function M.refresh(bufnr, invalidate_compare_text, callback)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    if callback then
      callback()
    end
    return
  end

  if invalidate_compare_text then
    buf_cache.compare_text = nil
    buf_cache.compare_text_index = nil
    buf_cache.force_next_update = true

    dot.git.cmd.get_file_info_async(buf_cache.repo.toplevel, buf_cache.relpath, function(file_info)
      if not cache[bufnr] then
        if callback then
          callback()
        end
        return
      end

      buf_cache.mode_bits = file_info and file_info.mode_bits
      buf_cache.object_name = file_info and file_info.object_name

      update_hunks(buf_cache, callback)
    end)
  else
    buf_cache.force_next_update = true
    update_hunks(buf_cache, callback)
  end
end

---@param callback                   fun()|nil
function M.refresh_all(callback)
  if repo then
    dot.git.cmd.get_abbrev_head_async(repo.toplevel, function(abbrev_head)
      if repo then
        repo.abbrev_head = abbrev_head
        dot.git.state.o_branch:next(abbrev_head)
      end
    end)
  end

  local bufnrs = vim.tbl_keys(cache)
  local visible_bufnrs = {} ---@type integer[]
  for _, bufnr in ipairs(bufnrs) do
    local buf_cache = cache[bufnr]
    if buf_cache then
      if is_buf_visible(bufnr) then
        buf_cache.dirty = false
        visible_bufnrs[#visible_bufnrs + 1] = bufnr
      else
        buf_cache.dirty = true
      end
    end
  end

  local remaining = #visible_bufnrs

  if remaining == 0 then
    if callback then
      callback()
    end
    return
  end

  for _, bufnr in ipairs(visible_bufnrs) do
    M.refresh(bufnr, true, function()
      remaining = remaining - 1
      if remaining == 0 and callback then
        callback()
      end
    end)
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

  local hunk ---@type dot.module.git.Hunk|nil
  if range then
    hunk = dot.git.hunk.create_partial(buf_cache.hunks, range[1], range[2])
  else
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
    hunk = dot.git.hunk.find(lnum, buf_cache.hunks)
  end

  if not hunk then
    return false, "No hunk at cursor"
  end

  local start_line = hunk.added.start - 1
  local end_line = start_line + hunk.added.count

  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, hunk.removed.lines)

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
  dot.git.cmd.stage_file_async(buf_cache.repo.toplevel, relpath, function(ok)
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

  local hunk ---@type dot.module.git.Hunk|nil
  if range then
    hunk = dot.git.hunk.create_partial(buf_cache.hunks, range[1], range[2])
  else
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
    hunk = dot.git.hunk.find(lnum, buf_cache.hunks)
  end

  if not hunk then
    if callback then
      callback(false, "No hunk at cursor")
    end
    return
  end

  local toplevel = buf_cache.repo.toplevel
  local relpath = buf_cache.relpath
  local mode_bits = buf_cache.mode_bits
  local file = buf_cache.file

  local function do_stage()
    local patch = dot.git.hunk.create_patch(relpath, hunk, mode_bits, false)
    dot.git.cmd.apply_patch_async(toplevel, patch, false, function(ok, err)
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
    dot.git.cmd.add_intent_to_add_async(toplevel, relpath, function()
      dot.git.cmd.get_file_info_async(toplevel, file, function(file_info)
        buf_cache.mode_bits = file_info and file_info.mode_bits
        buf_cache.object_name = file_info and file_info.object_name
        mode_bits = buf_cache.mode_bits
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
---@param hunks                      dot.module.git.Hunk[]  Staged hunks (HEAD vs Index diff)
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

    if count_in_index == 0 then
      for i = current_line, start_in_index do
        result[#result + 1] = index_lines[i]
      end
      current_line = start_in_index + 1
    else
      for i = current_line, start_in_index - 1 do
        result[#result + 1] = index_lines[i]
      end
      current_line = start_in_index + count_in_index
    end

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

  local selected_hunks = {} ---@type dot.module.git.Hunk[]

  if range then
    local top, bot = range[1], range[2] ---@type integer, integer
    for _, hunk in ipairs(hunks_staged) do
      if not (hunk.vend < top or hunk.added.start > bot) then
        selected_hunks[#selected_hunks + 1] = hunk
      end
    end
  else
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
    local hunk = dot.git.hunk.find(lnum, hunks_staged)
    if hunk then
      selected_hunks[1] = hunk
    end
  end

  if #selected_hunks == 0 then
    if callback then
      callback(false, "No staged hunk at cursor")
    end
    return
  end

  local new_index_lines = apply_inverted_hunks(index_lines, head_lines, selected_hunks)
  local toplevel = buf_cache.repo.toplevel
  local relpath = buf_cache.relpath
  local mode_bits = buf_cache.mode_bits or "100644"

  dot.git.cmd.hash_object_async(toplevel, relpath, new_index_lines, function(hash)
    if not hash then
      if callback then
        callback(false, "Failed to hash object")
      end
      return
    end

    dot.git.cmd.update_index_async(toplevel, mode_bits, hash, relpath, function(ok)
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

  ---@type ark.timer.IDisposableCallable
  local buf_enter_debounced = ark.timer.debounce(function(bufnr)
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

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_is_valid(buf) then
      M.attach(buf)
    end
  end
end

return M
