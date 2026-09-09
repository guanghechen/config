---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.buffer" ---@type string

local THROTTLE_MS = 200 ---@type integer

---@class era.m.git.buffer
local M = {}

---@type stl.c.Ticker
M.ticker = stl.c.Ticker.new()

---@type table<integer, era.m.git.buffer.ICache>
local cache = {}

---@type era.m.git.Repo|nil
local repo = nil

---@type table<integer, table>
local attach_owners = {}

--- The Neovim listener follows buffer lifetime; Git cache ownership follows the
--- current pathname and may be rebound by BufFilePost.
---@type table<integer, true>
local buffer_listeners = {}

---@param bufnr                      integer
---@return table
local function claim_attach(bufnr)
  local owner = {} ---@type table
  attach_owners[bufnr] = owner
  return owner
end

----------------------------------------------------------------------------------------------------
-- Update lock mechanism
-- Prevents concurrent updates to the same buffer and queues pending updates
----------------------------------------------------------------------------------------------------

---@class era.m.git.buffer.IUpdateLock
---@field public running              boolean
---@field public scheduled            boolean
---@field public pending              era.m.git.buffer.IUpdateWaiter[]

---@class era.m.git.buffer.IUpdateWaiter
---@field public resolve              fun(result: nil): nil
---@field public reject               fun(err: string): nil

---@type table<integer, era.m.git.buffer.IUpdateLock>
local update_locks = {}

---@param bufnr                         integer
---@return era.m.git.buffer.IUpdateLock
local function get_update_lock(bufnr)
  if not update_locks[bufnr] then
    update_locks[bufnr] = {
      running = false,
      scheduled = false,
      pending = {},
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

---@param bufnr                      integer
---@return nil
local function refresh_dirty_if_visible(bufnr)
  local buf_cache = cache[bufnr] ---@type era.m.git.buffer.ICache|nil
  if not buf_cache or not buf_cache.dirty or not is_buf_visible(bufnr) then
    return
  end

  -- Consume the deferred work before starting so duplicate enter events cannot start parallel queries.
  buf_cache.dirty = false
  M.refresh(bufnr, true):finally(function(resolved)
    if not resolved and cache[bufnr] == buf_cache then
      buf_cache.dirty = true
    end
  end)
end

---@class era.m.git.buffer.IBatchInvalidateOpts
---@field public clear_head_document    ?boolean
---@field public clear_index_document   ?boolean
---@field public clear_object_name      ?boolean
---@field public delay_interval         integer

---@param opts                          era.m.git.buffer.IBatchInvalidateOpts
local function batch_invalidate_and_refresh(opts)
  local visible_buffers = {} ---@type integer[]

  for bufnr, buf_cache in pairs(cache) do
    if buf_cache then
      if opts.clear_head_document then
        buf_cache.head_document = nil
      end
      if opts.clear_index_document then
        buf_cache.index_document = nil
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

---@param template                      era.m.git.Document
---@return era.m.git.Document
local function empty_document(template)
  return era.m.git.staging.from_text("", {
    bomb = template.bomb,
    default_eol = template.eol,
    encoding = template.encoding,
  })
end

---@param result                        stl.git.IBlobResult
---@param template                      era.m.git.Document
---@param missing_is_empty              boolean
---@return era.m.git.Document|nil
---@return string|nil
local function document_from_blob_result(result, template, missing_is_empty)
  if type(result) ~= "table" then
    return nil, "Invalid Git blob result"
  end
  if result.ok then
    if type(result.bytes) ~= "string" then
      return nil, "Git blob result has no bytes"
    end
    return era.m.git.staging.from_blob(result.bytes, template.encoding, template.eol)
  end
  if result.missing and missing_is_empty then
    return empty_document(template), nil
  end
  return nil, result.err or "Failed to read Git blob"
end

---@param result                        stl.git.IFileInfoResult
---@return stl.git.IFileInfo|nil
---@return string|nil
local function file_info_from_result(result)
  if type(result) ~= "table" then
    return nil, "Invalid Git file info result"
  end
  if result.ok then
    if not result.info then
      return nil, "Git file info result has no entry"
    end
    if result.info.has_conflicts then
      return nil, "Cannot operate on an unmerged index entry"
    end
    return result.info, nil
  end
  if result.missing then
    return nil, nil
  end
  return nil, result.err or "Failed to inspect Git index"
end

---@param buf_cache                  era.m.git.buffer.ICache
---@return stl.c.Future              Resolves with nil when done
local function update_hunks(buf_cache)
  ---@diagnostic disable-next-line: redundant-parameter -- LuaLS selects the one-argument overload for Future.new.
  return stl.c.Future.new(function(resolve, reject)
    local bufnr = buf_cache.bufnr ---@type integer

    if not vim.api.nvim_buf_is_valid(bufnr) then
      resolve(nil)
      return
    end

    local lock = get_update_lock(bufnr)

    -- If already scheduled or running, add resolver to pending list
    if lock.scheduled or lock.running then
      lock.pending[#lock.pending + 1] = { resolve = resolve, reject = reject }
      lock.scheduled = true
      return
    end

    local buffer_document = era.m.git.staging.from_buffer(bufnr) ---@type era.m.git.Document
    local document_format = table.concat({
      buffer_document.encoding,
      buffer_document.eol,
      buffer_document.bomb and "1" or "0",
    }, ":") ---@type string
    if buf_cache.document_format ~= document_format then
      buf_cache.document_format = document_format
      buf_cache.head_document = nil
      buf_cache.index_document = nil
      buf_cache.force_next_update = true
    end

    local tick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
    if tick == buf_cache.changedtick and not buf_cache.force_next_update then
      resolve(nil)
      return
    end

    lock.running = true
    buf_cache.changedtick = tick
    local should_force_update = buf_cache.force_next_update ---@type boolean
    buf_cache.force_next_update = false

    local old_hunks = buf_cache.hunks ---@type era.m.git.Hunk[]|nil
    local old_hunks_staged = buf_cache.hunks_staged ---@type era.m.git.Hunk[]|nil

    local toplevel = buf_cache.repo.toplevel ---@type string
    local relpath = buf_cache.relpath ---@type string

    local function run_scheduled_update()
      if not lock.scheduled then
        return
      end
      lock.scheduled = false
      local pending = lock.pending ---@type era.m.git.buffer.IUpdateWaiter[]
      lock.pending = {}
      vim.schedule(function()
        local current_cache = cache[bufnr]
        if current_cache and current_cache.attached then
          update_hunks(current_cache):finally(function(resolved, result)
            for _, waiter in ipairs(pending) do
              if resolved then
                waiter.resolve(nil)
              else
                waiter.reject(result)
              end
            end
          end)
        else
          for _, waiter in ipairs(pending) do
            waiter.resolve(nil)
          end
        end
      end)
    end

    ---@param ok                        boolean
    ---@param err                       string|nil
    local function settle(ok, err)
      lock.running = false
      if ok then
        resolve(nil)
      else
        reject(err or "Failed to update Git hunks")
      end
      run_scheduled_update()
    end

    ---@param err                       string
    local function fail(err)
      if cache[bufnr] == buf_cache then
        buf_cache.dirty = true
        buf_cache.force_next_update = true
        stl.reporter.warn({
          from = __module_name__,
          subject = "update_hunks",
          message = err,
        })
      end
      settle(false, err)
    end

    local function finish()
      if not vim.api.nvim_buf_is_valid(bufnr) or cache[bufnr] ~= buf_cache then
        lock.running = false
        lock.scheduled = false
        -- Resolve all pending resolvers
        for _, waiter in ipairs(lock.pending) do
          waiter.resolve(nil)
        end
        lock.pending = {}
        resolve(nil)
        return
      end

      local head_document = buf_cache.head_document ---@type era.m.git.Document|nil
      local index_document = buf_cache.index_document ---@type era.m.git.Document|nil
      if not head_document or not index_document then
        fail("Git comparison documents are incomplete")
        return
      end
      buf_cache.untracked = buf_cache.object_name == nil

      local function on_diff_complete()
        if not vim.api.nvim_buf_is_valid(bufnr) or cache[bufnr] ~= buf_cache then
          lock.running = false
          lock.scheduled = false
          -- Resolve all pending resolvers
          for _, waiter in ipairs(lock.pending) do
            waiter.resolve(nil)
          end
          lock.pending = {}
          resolve(nil)
          return
        end

        era.m.git.hunk.set(bufnr, buf_cache.hunks)

        local hunks_changed = era.m.git.hunk.compare_heads(buf_cache.hunks, old_hunks) ---@type boolean
        local hunks_staged_changed = era.m.git.hunk.compare_heads(buf_cache.hunks_staged, old_hunks_staged) ---@type boolean

        if should_force_update or hunks_changed or hunks_staged_changed then
          era.m.git.sign.update(bufnr, buf_cache.hunks, buf_cache.hunks_staged, {
            untracked = buf_cache.untracked,
            force = should_force_update,
          })
          M.ticker:tick()
        end

        buf_cache.dirty = false

        settle(true, nil)
      end

      era.m.git.diff.run_diff_future(index_document.lines, buffer_document.lines):finally(function(ok, hunks)
        if not ok then
          on_diff_complete()
          return
        end
        buf_cache.hunks = hunks

        era.m.git.diff.run_diff_future(head_document.lines, buffer_document.lines):finally(function(ok_head, hunks_head)
          if ok_head then
            buf_cache.hunks_staged = era.m.git.diff.filter_secondary(buf_cache.hunks, hunks_head)
          end
          on_diff_complete()
        end)
      end)
    end

    local need_head = not buf_cache.head_document ---@type boolean
    local need_index = not buf_cache.index_document ---@type boolean
    local object_name = buf_cache.object_name ---@type string|nil

    if not need_head and not need_index then
      finish()
      return
    end

    if need_index and not object_name then
      buf_cache.index_document = empty_document(buffer_document)
      need_index = false
    end

    if not need_head and not need_index then
      finish()
      return
    end

    ---@type stl.c.Future[]
    local futures = {}
    local head_future_idx = nil ---@type integer|nil
    local index_future_idx = nil ---@type integer|nil

    if need_head then
      head_future_idx = #futures + 1
      futures[head_future_idx] = stl.git.info.get_show_blob(toplevel, "HEAD:" .. relpath)
    end

    if need_index then
      index_future_idx = #futures + 1
      futures[index_future_idx] = stl.git.info.get_show_blob(toplevel, object_name --[[@as string]])
    end

    stl.c.Future.all(futures):finally(function(resolved, results)
      if not resolved or type(results) ~= "table" then
        fail(type(results) == "string" and results or "Failed to load Git comparison documents")
        return
      end

      if head_future_idx then
        local result = results[head_future_idx] ---@type stl.git.IBlobResult
        local document, err = document_from_blob_result(result, buffer_document, true)
        if not document then
          fail("Failed to load HEAD: " .. (err or "unknown error"))
          return
        end
        buf_cache.head_document = document
      end

      if index_future_idx then
        local result = results[index_future_idx] ---@type stl.git.IBlobResult
        local document, err = document_from_blob_result(result, buffer_document, false)
        if not document then
          fail("Failed to load index: " .. (err or "unknown error"))
          return
        end
        buf_cache.index_document = document
      end

      finish()
    end)
  end)
end

---@param bufnr                      integer
---@return string|nil
local function resolve_attach_file(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ~= "" then
    return nil
  end

  local file = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if file == "" or not dot.path.is_git_repo() then
    return nil
  end

  file = dot.path.normalize(file)
  local workspace = dot.path.normalize(dot.path.workspace()) ---@type string
  return yoz.path.is_descendant(workspace, file) and file or nil
end

---@param bufnr                      integer
---@return boolean
local function ensure_buffer_listener(bufnr)
  if buffer_listeners[bufnr] then
    return true
  end

  local ok = vim.api.nvim_buf_attach(bufnr, false, {
    on_detach = function(_, buf)
      buffer_listeners[buf] = nil
      M.detach(buf)
    end,
    on_lines = function(_, buf, _, first, last_orig, last_new)
      local buf_cache = cache[buf]
      if not buf_cache then
        return
      end

      era.m.git.sign.on_lines(buf, last_orig, last_new)

      local check_start = first + 1 ---@type integer
      local check_end = math.max(last_orig, last_new) ---@type integer
      if buf_cache.hunks and era.m.git.sign.contains_range(buf, check_start, check_end) then
        buf_cache.force_next_update = true
      elseif buf_cache.hunks_staged and era.m.git.sign.contains_range(buf, check_start, check_end) then
        buf_cache.force_next_update = true
      end

      if is_buf_visible(buf) and buf_cache.update_throttled then
        buf_cache.update_throttled()
      else
        buf_cache.dirty = true
      end
    end,
    on_reload = function(_, buf)
      local buf_cache = cache[buf]
      if not buf_cache then
        return
      end
      buf_cache.force_next_update = true
      if is_buf_visible(buf) and buf_cache.update_throttled then
        buf_cache.update_throttled()
      else
        buf_cache.dirty = true
      end
    end,
  })

  if ok then
    buffer_listeners[bufnr] = true
  end
  return ok
end

---@param bufnr                      integer
---@param opts                       { force: boolean|nil }|nil
---@return boolean
function M.attach(bufnr, opts)
  opts = opts or {}

  local file = resolve_attach_file(bufnr) ---@type string|nil
  if not file then
    M.detach(bufnr)
    return false
  end

  local current = cache[bufnr] ---@type era.m.git.buffer.ICache|nil
  if current and current.file == file and not opts.force then
    return true
  end
  if current then
    M.detach(bufnr)
  end
  local owner = claim_attach(bufnr) ---@type table

  local function do_attach(r)
    if attach_owners[bufnr] ~= owner then
      return
    end

    ---@return nil
    local function abandon()
      if attach_owners[bufnr] == owner then
        attach_owners[bufnr] = nil
      end
    end

    if not r then
      abandon()
      return
    end

    if resolve_attach_file(bufnr) ~= file then
      abandon()
      return
    end

    if not yoz.path.is_descendant(r.toplevel, file) then
      abandon()
      return
    end

    if not ensure_buffer_listener(bufnr) then
      stl.reporter.warn({
        from = __module_name__,
        subject = "attach",
        message = "Failed to attach buffer listener",
        details = { bufnr = bufnr, file = file },
      })
      abandon()
      return
    end

    local relpath = r:get_relpath(file)

    ---@type era.m.git.buffer.ICache
    local buf_cache = {
      attached = true,
      bufnr = bufnr,
      changedtick = -1,
      document_format = nil,
      head_document = nil,
      index_document = nil,
      dirty = true,
      file = file,
      force_next_update = true,
      hunks = nil,
      hunks_staged = nil,
      mode_bits = nil,
      object_name = nil,
      relpath = relpath,
      repo = r,
      untracked = false,
      update_throttled = nil,
    }

    buf_cache.update_throttled = stl.timer.throttle(function()
      if cache[bufnr] and buf_cache.attached then
        update_hunks(buf_cache)
      end
    end, THROTTLE_MS)

    cache[bufnr] = buf_cache
    attach_owners[bufnr] = nil
    refresh_dirty_if_visible(bufnr)
  end

  if repo then
    do_attach(repo)
    return true
  end

  local toplevel = dot.path.workspace() ---@type string
  era.m.git.repo.create(toplevel):finally(function(resolved, r)
    if resolved and r then
      repo = r
      era.m.git.state.o_branch:next(r.abbrev_head)
      era.m.git.watcher.update(r.gitdir, r.commondir)
    end
    do_attach(r)
  end)

  return true
end

---@param bufnr                      integer
---@return nil
function M.detach(bufnr)
  attach_owners[bufnr] = nil
  local buf_cache = cache[bufnr]
  if not buf_cache then
    return
  end

  buf_cache.attached = false
  clear_update_lock(bufnr)

  if buf_cache.update_throttled then
    buf_cache.update_throttled:dispose()
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
    clear_head_document = true,
    clear_index_document = true,
    clear_object_name = true,
    delay_interval = 15,
  })
end

function M.invalidate_index_all()
  batch_invalidate_and_refresh({
    clear_index_document = true,
    clear_object_name = true,
    delay_interval = 20,
  })
end

function M.mark_dirty_all()
  batch_invalidate_and_refresh({
    clear_index_document = true,
    clear_object_name = true,
    delay_interval = 10,
  })
end

---@param bufnr                      integer
---@param invalidate_index          ?boolean
---@return stl.c.Future              Resolves with nil when done; rejects when refresh fails
function M.refresh(bufnr, invalidate_index)
  ---@diagnostic disable-next-line: redundant-parameter -- LuaLS selects the one-argument overload for Future.new.
  return stl.c.Future.new(function(resolve, reject)
    local buf_cache = cache[bufnr]
    if not buf_cache then
      resolve(nil)
      return
    end

    local function fail(err)
      if cache[bufnr] == buf_cache then
        buf_cache.dirty = true
        buf_cache.force_next_update = true
      end
      reject(err)
    end

    local function refresh_hunks()
      update_hunks(buf_cache):finally(function(resolved, result)
        if resolved then
          resolve(nil)
        else
          fail(result)
        end
      end)
    end

    if invalidate_index then
      stl.git.info.get_file_info(buf_cache.repo.toplevel, buf_cache.relpath):finally(function(resolved, result)
        if cache[bufnr] ~= buf_cache then
          resolve(nil)
          return
        end

        if not resolved then
          buf_cache.index_document = nil
          fail(result)
          return
        end

        local file_info, err = file_info_from_result(result)
        if err then
          buf_cache.index_document = nil
          fail(err)
          return
        end

        local new_object_name = file_info and file_info.object_name
        local old_object_name = buf_cache.object_name

        if new_object_name ~= old_object_name then
          buf_cache.index_document = nil
        end

        buf_cache.mode_bits = file_info and file_info.mode_bits
        buf_cache.object_name = new_object_name
        buf_cache.force_next_update = true
        refresh_hunks()
      end)
    else
      buf_cache.force_next_update = true
      refresh_hunks()
    end
  end)
end

---@param on_error                      fun(err: string): nil
---@param callback                      function
---@return function
local function protected_callback(on_error, callback)
  return function(...)
    local args = { n = select("#", ...), ... }
    local ok, err = xpcall(function()
      callback(unpack(args, 1, args.n))
    end, debug.traceback)
    if not ok then
      on_error(tostring(err))
    end
  end
end

---@param template                      era.m.git.Document
---@param text                          string
---@return era.m.git.Document
local function document_with_text(template, text)
  local document = era.m.git.staging.from_text(text, {
    bomb = template.bomb,
    default_eol = template.eol,
    encoding = template.encoding,
  })
  -- VS Code encodes the exact string returned by applyLineChanges; it does not normalize the
  -- original and modified documents' EOLs a second time before `hash-object --path`.
  document.text = text
  return document
end

---@class era.m.git.buffer.IIndexSnapshot
---@field public document               era.m.git.Document
---@field public object_name            string|nil

---@param toplevel                      string
---@param relpath                       string
---@param template                      era.m.git.Document
---@return stl.c.Future
local function load_index_context(toplevel, relpath, template)
  ---@diagnostic disable-next-line: redundant-parameter -- LuaLS selects the one-argument overload for Future.new.
  return stl.c.Future.new(function(resolve, reject)
    stl.git.info.get_file_info(toplevel, relpath):finally(protected_callback(reject, function(resolved, result)
      if not resolved then
        reject(result)
        return
      end
      local file_info, info_err = file_info_from_result(result)
      if info_err then
        reject(info_err)
        return
      end
      if not file_info or not file_info.object_name then
        stl.git.info
          .get_head_file_mode(toplevel, relpath)
          :finally(protected_callback(reject, function(mode_resolved, mode_result)
            if not mode_resolved or type(mode_result) ~= "table" then
              reject(type(mode_result) == "string" and mode_result or "Failed to inspect HEAD mode")
              return
            end
            if not mode_result.ok and not mode_result.missing then
              reject(mode_result.err or "Failed to inspect HEAD mode")
              return
            end
            resolve({
              add = true,
              document = empty_document(template),
              mode_bits = mode_result.mode_bits or "100644",
              object_name = nil,
            })
          end))
        return
      end

      stl.git.info
        .get_show_blob(toplevel, file_info.object_name)
        :finally(protected_callback(reject, function(blob_resolved, blob_result)
          if not blob_resolved then
            reject(blob_result or "Failed to read index blob")
            return
          end
          local document, err = document_from_blob_result(blob_result, template, false)
          if not document then
            reject(err or "Failed to read index blob")
            return
          end
          resolve({
            add = false,
            document = document,
            mode_bits = file_info.mode_bits or "100644",
            object_name = file_info.object_name,
          })
        end))
    end))
  end)
end

---@param toplevel                      string
---@param relpath                       string
---@param template                      era.m.git.Document
---@return stl.c.Future
local function load_head_document(toplevel, relpath, template)
  ---@diagnostic disable-next-line: redundant-parameter -- LuaLS selects the one-argument overload for Future.new.
  return stl.c.Future.new(function(resolve, reject)
    stl.git.info
      .get_show_blob(toplevel, "HEAD:" .. relpath)
      :finally(protected_callback(reject, function(resolved, result)
        if not resolved then
          reject(result)
          return
        end
        local document, err = document_from_blob_result(result, template, true)
        if not document then
          reject(err or "Failed to read HEAD blob")
          return
        end
        resolve(document)
      end))
  end)
end

---@param toplevel                      string
---@param relpath                       string
---@param document                      era.m.git.Document
---@param mode_bits                     string
---@param add                           boolean
---@return stl.c.Future
local function write_index_document(toplevel, relpath, document, mode_bits, add)
  return stl.c.Future.new(function(resolve)
    local finished = false ---@type boolean
    ---@param result                    { ok: boolean, err: string|nil }
    local function finish(result)
      if finished then
        return
      end
      finished = true
      resolve(result)
    end

    local function fail(err)
      finish({ ok = false, err = tostring(err) })
    end

    local ok, err = xpcall(function()
      local bytes, encode_err = era.m.git.staging.encode(document)
      if not bytes then
        finish({ ok = false, err = encode_err or "Failed to encode document" })
        return
      end

      stl.git.act.hash_object(toplevel, relpath, bytes):finally(protected_callback(fail, function(hash_resolved, hash)
        if not hash_resolved or not hash then
          finish({ ok = false, err = "Failed to hash document" })
          return
        end
        stl.git.act
          .update_index(toplevel, mode_bits, hash, relpath, nil, add)
          :finally(protected_callback(fail, function(updated, updated_ok)
            if updated and updated_ok then
              finish({ ok = true, err = nil })
            else
              finish({ ok = false, err = "Failed to update index" })
            end
          end))
      end))
    end, debug.traceback)
    if not ok then
      fail(err)
    end
  end)
end

---@param toplevel                      string
---@param task                          fun(finish: fun(result: { ok: boolean, err: string|nil }): nil): nil
---@return stl.c.Future
local function with_index_write(toplevel, task)
  return era.m.git.index.run(toplevel, function(resolve)
    local finished = false ---@type boolean
    ---@param result                    { ok: boolean, err: string|nil }
    local function finish(result)
      if finished then
        return
      end
      finished = true
      resolve(result)
    end

    local ok, err = pcall(task, finish)
    if not ok then
      finish({ ok = false, err = tostring(err) })
    end
  end)
end

---@param bufnr                      integer
---@return boolean
function M.reset_buffer(bufnr)
  local buf_cache = cache[bufnr]
  if not buf_cache or not buf_cache.index_document then
    return false
  end
  if buf_cache.untracked then
    return false
  end

  era.m.git.staging.replace_buffer_text(bufnr, buf_cache.index_document.text)
  return true
end

---@param bufnr                         integer
---@param range                         ?{ [1]: integer, [2]: integer }
---@return boolean
---@return string|nil
function M.reset_hunk(bufnr, range)
  local buf_cache = cache[bufnr]
  if not buf_cache or not buf_cache.index_document then
    return false, "Buffer not attached"
  end
  if buf_cache.untracked then
    return false, "Untracked files have no index content to restore"
  end

  local buffer_document = era.m.git.staging.from_buffer(bufnr) ---@type era.m.git.Document
  local index_document = buf_cache.index_document ---@type era.m.git.Document
  local hunks = era.m.git.diff.run_diff(index_document.lines, buffer_document.lines) ---@type era.m.git.Hunk[]
  if not range then
    local lnum = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1] ---@type integer
    range = { lnum, lnum }
  end

  local text = era.m.git.staging.apply_selection(index_document, buffer_document, hunks, range[1], range[2], "reset")
  if text == nil then
    return false, "No hunk at cursor"
  end

  era.m.git.staging.replace_buffer_text(bufnr, text)
  return true, nil
end

---@param bufnr                      integer
---@return stl.c.Future              Resolves with boolean (success)
function M.stage_buffer(bufnr)
  local buf_cache = cache[bufnr]
  if not buf_cache then
    return stl.c.Future.resolve(false)
  end

  local toplevel = buf_cache.repo.toplevel ---@type string
  local relpath = buf_cache.relpath ---@type string
  return with_index_write(toplevel, function(finish)
    stl.git.act.stage_file(toplevel, relpath):finally(function(resolved, ok)
      local success = resolved and ok == true ---@type boolean
      local err = nil ---@type string|nil
      if not success then
        err = tostring(ok or "Failed to stage file")
      end
      finish({ ok = success, err = err })
    end)
  end):map(function(result)
    return result.ok
  end)
end

---@class era.m.git.buffer.IStageRangeOpts
---@field public buffer_document        era.m.git.Document
---@field public expected_index         era.m.git.buffer.IIndexSnapshot
---@field public partial                boolean
---@field public range                  { [1]: integer, [2]: integer }
---@field public relpath                string
---@field public toplevel               string

---@param opts                          era.m.git.buffer.IStageRangeOpts
---@return stl.c.Future
function M.stage_range(opts)
  return with_index_write(opts.toplevel, function(finish)
    load_index_context(opts.toplevel, opts.relpath, opts.buffer_document):finally(protected_callback(function(err)
      finish({ ok = false, err = err })
    end, function(loaded, context)
      if not loaded or type(context) ~= "table" then
        finish({ ok = false, err = type(context) == "string" and context or "Failed to load index" })
        return
      end

      local index_document = context.document ---@type era.m.git.Document
      if
        context.object_name ~= opts.expected_index.object_name
        or index_document.text ~= opts.expected_index.document.text
      then
        finish({ ok = false, err = "The index changed since the hunk was drawn; try again" })
        return
      end

      local hunks = era.m.git.diff.run_diff(index_document.lines, opts.buffer_document.lines) ---@type era.m.git.Hunk[]
      local text = era.m.git.staging.apply_selection(
        index_document,
        opts.buffer_document,
        hunks,
        opts.range[1],
        opts.range[2],
        opts.partial and "stage_partial" or "stage"
      )
      if text == nil then
        finish({ ok = false, err = "The selection range does not contain any changes" })
        return
      end

      local document = document_with_text(opts.buffer_document, text) ---@type era.m.git.Document
      write_index_document(opts.toplevel, opts.relpath, document, context.mode_bits, context.add):finally(
        protected_callback(function(err)
          finish({ ok = false, err = err })
        end, function(resolved, result)
          if resolved and type(result) == "table" then
            finish(result)
          else
            finish({ ok = false, err = type(result) == "string" and result or "Failed to write index" })
          end
        end)
      )
    end))
  end)
end

---@param bufnr                      integer
---@param range                      ?{ [1]: integer, [2]: integer }
---@return stl.c.Future              Resolves with { ok: boolean, err: ?string }
function M.stage_hunk(bufnr, range)
  local buf_cache = cache[bufnr]
  if not buf_cache or not buf_cache.index_document then
    return stl.c.Future.resolve({ ok = false, err = "Buffer not attached" })
  end

  local partial = range ~= nil ---@type boolean
  if not range then
    local lnum = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1] ---@type integer
    range = { lnum, lnum }
  end

  local future = M.stage_range({
    buffer_document = era.m.git.staging.from_buffer(bufnr),
    expected_index = {
      document = buf_cache.index_document,
      object_name = buf_cache.object_name,
    },
    partial = partial,
    range = range,
    relpath = buf_cache.relpath,
    toplevel = buf_cache.repo.toplevel,
  })
  return future:then_(function(result)
    if not result.ok then
      return result
    end
    return stl.c.Future.new(function(resolve)
      M.refresh(bufnr, true):finally(function()
        resolve(result)
      end)
    end)
  end)
end

---@class era.m.git.buffer.IUnstageRangeOpts
---@field public expected_index         era.m.git.buffer.IIndexSnapshot
---@field public range                  { [1]: integer, [2]: integer }
---@field public relpath                string
---@field public toplevel               string

---@param opts                          era.m.git.buffer.IUnstageRangeOpts
---@return stl.c.Future
function M.unstage_range(opts)
  return with_index_write(opts.toplevel, function(finish)
    load_index_context(opts.toplevel, opts.relpath, opts.expected_index.document):finally(
      protected_callback(function(err)
        finish({ ok = false, err = err })
      end, function(index_loaded, context)
        if not index_loaded or type(context) ~= "table" or context.add then
          finish({ ok = false, err = "The file has no index content to unstage partially" })
          return
        end

        local index_document = context.document ---@type era.m.git.Document
        if
          context.object_name ~= opts.expected_index.object_name
          or index_document.text ~= opts.expected_index.document.text
        then
          finish({ ok = false, err = "The index changed since the staged diff was drawn; try again" })
          return
        end

        load_head_document(opts.toplevel, opts.relpath, opts.expected_index.document):finally(
          protected_callback(function(err)
            finish({ ok = false, err = err })
          end, function(head_loaded, head_document)
            if not head_loaded or type(head_document) ~= "table" then
              finish({ ok = false, err = type(head_document) == "string" and head_document or "Failed to load HEAD" })
              return
            end

            local hunks = era.m.git.diff.run_diff(head_document.lines, index_document.lines) ---@type era.m.git.Hunk[]
            local text = era.m.git.staging.apply_selection(
              head_document,
              index_document,
              hunks,
              opts.range[1],
              opts.range[2],
              "unstage"
            )
            if text == nil then
              finish({ ok = false, err = "The selection range does not contain any staged changes" })
              return
            end

            local document = document_with_text(opts.expected_index.document, text) ---@type era.m.git.Document
            write_index_document(opts.toplevel, opts.relpath, document, context.mode_bits, false):finally(
              protected_callback(function(err)
                finish({ ok = false, err = err })
              end, function(resolved, result)
                if resolved and type(result) == "table" then
                  finish(result)
                else
                  finish({ ok = false, err = type(result) == "string" and result or "Failed to write index" })
                end
              end)
            )
          end)
        )
      end)
    )
  end)
end

---@param bufnr                      integer
---@param range                      ?{ [1]: integer, [2]: integer }
---@return stl.c.Future
---@diagnostic disable-next-line: unused-local -- Signature is retained for the public hunk action contract.
function M.unstage_hunk(bufnr, range)
  return stl.c.Future.resolve({
    ok = false,
    err = "Open the staged diff and run unstage from its index-side window",
  })
end

---@return nil
function M.setup()
  local augroup = vim.api.nvim_create_augroup("DotModuleGitBuffer", { clear = true }) ---@type integer

  local pending_visible_bufnrs = {} ---@type table<integer, true>

  local refresh_visible_debounced = stl.timer.debounce(function()
    local bufnrs = pending_visible_bufnrs
    pending_visible_bufnrs = {}
    for bufnr in pairs(bufnrs) do
      refresh_dirty_if_visible(bufnr)
    end
  end, 50)

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufFilePost" }, {
    group = augroup,
    callback = function(args)
      M.attach(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = function(args)
      local current = cache[args.buf] ---@type era.m.git.buffer.ICache|nil
      if M.attach(args.buf) and current and cache[args.buf] == current then
        M.refresh(args.buf, true)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = augroup,
    callback = function(args)
      pending_visible_bufnrs[args.buf] = true
      refresh_visible_debounced()
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
      if buf_cache.update_throttled then
        buf_cache.update_throttled()
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
