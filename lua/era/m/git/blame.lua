---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.blame" ---@type string

local jobs = require("era.m.git.job")
local exiting = false ---@type boolean

local NS_INLINE = "dot_module_git_inline_blame"
local NS_BUFFER = "dot_module_git_buffer_blame"

--- Sentinel rejection used when a blame run is superseded/cancelled; distinguished
--- from a real git error so we don't report it.
local CANCELLED = "blame:cancelled" ---@type string

---@class era.m.git.blame
local M = {}

--- Per-buffer whole-file blame, keyed by the buffer changedtick it was computed
--- against. A cached entry is served only while changedtick still matches; any
--- edit (or an explicit invalidate) makes it miss and re-blame.
---@class era.m.git.blame.ICacheEntry
---@field public snapshot               yoz.git.BlameSnapshot
---@field public owner                  era.m.git.buffer.ICache
---@field public tick                   integer
---@field public presentation           ?era.m.git.blame.IPresentation
---@type table<integer, era.m.git.blame.ICacheEntry>
local cache = {}

--- In-flight blame run per buffer: the token to cancel it and the changedtick it
--- was started for (so a duplicate request for the same content coalesces instead
--- of spawning a second git process).
---@class era.m.git.blame.IInflight
---@field public owner                  era.m.git.buffer.ICache
---@field public token                  stl.c.CancellationToken
---@field public tick                   integer
---@type table<integer, era.m.git.blame.IInflight>
local inline_inflight = {}
---@type table<integer, era.m.git.blame.IInflight>
local buffer_inflight = {}

--- Per-attachment changedtick whose blame run failed (untracked file, git error).
--- The same owner and tick then become a no-op instead of re-running git and
--- re-reporting on every cursor move. Invalidation and BufDelete clear it explicitly.
---@class era.m.git.blame.IFailedEntry
---@field public owner                  era.m.git.buffer.ICache
---@field public tick                   integer
---@type table<integer, era.m.git.blame.IFailedEntry>
local failed = {}

---Capture editor content on the owner thread; query and parsing run in the native worker.
---@param bufnr                         integer
---@param relpath                       string
---@param cwd                           string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with yoz.git.BlameSnapshot
local function run_blame(bufnr, relpath, cwd, token)
  return jobs
    .run(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        error(CANCELLED, 0)
      end
      local contents, err = era.m.git.staging.encode(era.m.git.staging.from_buffer(bufnr))
      if not contents then
        error(err or "Failed to encode buffer content", 0)
      end
      return yoz.git.start_blame({ cwd = cwd, path = relpath, contents = contents })
    end, token)
    :then_(nil, function(err)
      error(err == "Operation cancelled" and CANCELLED or err, 0)
    end)
end

---@param bufnr                         integer
---@param result                        string
local function report_failure(bufnr, result)
  if result == CANCELLED then
    return
  end
  stl.reporter.debug({
    from = __module_name__,
    group = "git",
    subject = "blame",
    message = string.format("git blame failed for buffer %d: %s", bufnr, result),
    -- Blame failure is an expected, recoverable condition (untracked file, no path
    -- in HEAD, transient git error). Record it in history for diagnosis, but never
    -- pop a window - otherwise every cursor move on such a file floods notifications.
    silent = true,
  })
end

----------------------------------------------------------------------------------------------------
-- Inline blame
----------------------------------------------------------------------------------------------------

---@class era.m.git.blame.IInlineConfig
---@field public delay                  integer
---@field public enabled                boolean
---@field public formatter              string
---@field public hl_group               string
---@field public prefix                 string
---@field public priority               integer
local inline_config = {
  delay = 500,
  enabled = true,
  formatter = "<author>, <author_time:%Y-%m-%d %H:%M:%S> - <summary>",
  hl_group = "m_git_inline_blame",
  prefix = "    ",
  priority = 200,
}

---@type integer
local inline_ns = vim.api.nvim_create_namespace(NS_INLINE)

---@type integer
local inline_augroup = vim.api.nvim_create_augroup("DotModuleGitInlineBlame", { clear = true })

---@param info                          yoz.git.BlameCommit
---@return boolean
local function is_current_user(info)
  local user_name = era.m.git.state.get_user_name()
  local user_email = era.m.git.state.get_user_email()
  if user_email and info.author_mail == user_email then
    return true
  end
  if user_name and info.author == user_name then
    return true
  end
  return false
end

---@param info                          yoz.git.BlameCommit
---@param fmt                           string
---@return string
local function format_blame(info, fmt)
  local values = {
    author = is_current_user(info) and "You" or info.author,
    author_mail = info.author_mail,
    committer = info.committer,
    committer_mail = info.committer_mail,
    summary = info.summary,
    sha = info.sha,
    abbrev_sha = info.abbrev_sha,
  }
  -- Metadata is literal text, not a gsub replacement or another formatter template.
  return (
    fmt:gsub("<([^>]+)>", function(field)
      if values[field] ~= nil then
        return values[field]
      end
      local time_field, date_fmt = field:match("^([%w_]+):(.+)$")
      if time_field == "author_time" or time_field == "committer_time" then
        return info[time_field] > 0 and (os.date(date_fmt, info[time_field]) or "") or ""
      end
    end)
  )
end

---@param bufnr                         integer
local function inline_reset(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, inline_ns, 1)
  end
end

---@param bufnr                         integer
---@param lnum                          integer
---@param info                          yoz.git.BlameCommit
---@return nil
local function inline_set_extmark(bufnr, lnum, info)
  local text = inline_config.prefix
    .. (info.uncommitted and "Not committed yet" or format_blame(info, inline_config.formatter))

  pcall(vim.api.nvim_buf_set_extmark, bufnr, inline_ns, lnum - 1, 0, {
    id = 1,
    virt_text = { { text, inline_config.hl_group } },
    virt_text_pos = "eol",
    priority = inline_config.priority,
    hl_mode = "combine",
  })
end

--- Paint (or clear) the inline annotation for the cursor line, fetching blame only
--- when the cache misses. Re-reads bufnr/win/lnum/changedtick on every call, so it
--- is safe to invoke directly OR from a settled blame `:finally` - it never paints
--- a result against a line/window/content other than the one current right now.
---@param bufnr                         integer
---@return nil
local function inline_update(bufnr)
  if
    exiting
    or not inline_config.enabled
    or not vim.api.nvim_buf_is_valid(bufnr)
    or vim.api.nvim_get_mode().mode == "i"
  then
    return
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if bufnr ~= vim.api.nvim_win_get_buf(winnr) then
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(winnr)[1] ---@type integer
  if vim.fn.foldclosed(lnum) ~= -1 then
    return
  end

  local buf_cache = era.m.git.buffer.get_cache(bufnr)
  if not buf_cache or buf_cache.untracked then
    inline_reset(bufnr) -- an untracked file has no blame to show; clear any stale value
    return
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer

  local entry = cache[bufnr]
  if entry and entry.tick == tick and entry.owner == buf_cache then
    local info = entry.snapshot:commit_at(lnum)
    if info then
      inline_set_extmark(bufnr, lnum, info)
    else
      inline_reset(bufnr)
    end
    return
  end

  -- This exact content already failed to blame; don't re-run git / re-report on
  -- every cursor move. A new changedtick (or invalidate) clears the marker and retries.
  local failed_entry = failed[bufnr] ---@type era.m.git.blame.IFailedEntry|nil
  if failed_entry and failed_entry.tick == tick and failed_entry.owner == buf_cache then
    return
  end

  -- A run for this exact content is already going; its :finally re-renders.
  local inflight = inline_inflight[bufnr]
  if inflight and inflight.tick == tick and inflight.owner == buf_cache and not inflight.token:is_cancelled() then
    return
  end
  if inflight then
    inflight.token:cancel()
  end

  local token = stl.c.CancellationToken.new()
  inline_inflight[bufnr] = { owner = buf_cache, token = token, tick = tick }

  run_blame(bufnr, buf_cache.relpath, buf_cache.repo.toplevel, token):finally(function(ok, result)
    local current = inline_inflight[bufnr]
    if not current or current.token ~= token then
      return
    end
    inline_inflight[bufnr] = nil

    if
      not inline_config.enabled
      or not vim.api.nvim_buf_is_valid(bufnr)
      or vim.api.nvim_buf_get_changedtick(bufnr) ~= tick
      or era.m.git.buffer.get_cache(bufnr) ~= buf_cache
    then
      return
    end

    if not ok then
      -- A cancelled/superseded run rejects with CANCELLED; it must NOT mark this tick
      -- failed. invalidate (HEAD move / write) cancels the in-flight run WITHOUT bumping
      -- changedtick, so a stale failed marker would suppress the very refresh it requested.
      if result ~= CANCELLED then
        failed[bufnr] = { owner = buf_cache, tick = tick }
      end
      report_failure(bufnr, result)
      return
    end

    failed[bufnr] = nil
    cache[bufnr] = { snapshot = result, owner = buf_cache, tick = tick }
    inline_update(bufnr)
  end)
end

--- One shared debounce for inline blame: it tracks only the most recent buffer, by
--- design - inline blame annotates the current line of the current window, so a
--- pending refresh for a buffer the user just left is intentionally superseded.
---@type stl.timer.IDisposableCallable
local inline_update_debounced = stl.timer.debounce(function(bufnr)
  inline_update(bufnr)
end, inline_config.delay)

local function inline_setup_autocmds()
  vim.api.nvim_clear_autocmds({ group = inline_augroup })
  if not inline_config.enabled then
    inline_update_debounced:cancel()
    return
  end

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = inline_augroup,
    callback = function(args)
      local bufnr = args.buf ---@type integer
      if era.m.git.buffer.is_attached(bufnr) then
        inline_reset(bufnr) -- clear immediately so a stale value is never shown while moving
        inline_update_debounced(bufnr)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave" }, {
    group = inline_augroup,
    callback = function(args)
      local bufnr = args.buf ---@type integer
      inline_reset(bufnr)
      inline_update_debounced:cancel()
      local inflight = inline_inflight[bufnr]
      if inflight then
        inflight.token:cancel()
      end
    end,
  })
end

----------------------------------------------------------------------------------------------------
-- Buffer blame
----------------------------------------------------------------------------------------------------

---@type integer
local buffer_ns = vim.api.nvim_create_namespace(NS_BUFFER)

---@type integer
local buffer_augroup = vim.api.nvim_create_augroup("DotModuleGitBufferBlame", { clear = true })

---@class era.m.git.blame.IBufferConfig
---@field public formatter              string
---@field public hl_group               string
---@field public priority               integer
local buffer_config = {
  formatter = "<author>, <author_time:%Y-%m-%d %H:%M:%S> - <summary>",
  hl_group = "m_git_buffer_blame",
  priority = 100,
}

---@class era.m.git.blame.IPresentation
---@field public lines                  string[]
---@field public formatter              string
---@field public user_name              ?string
---@field public user_email             ?string
---@field public timezone               ?string
---@field public zone                   ?string
---@field public locale                 ?string

---Only rendered text is cached in Lua; source blame data remains in the native snapshot.
---@param entry                         era.m.git.blame.ICacheEntry
---@return string[]
local function buffer_annotations(entry)
  local user_name = era.m.git.state.get_user_name()
  local user_email = era.m.git.state.get_user_email()
  local timezone = vim.env.TZ
  local zone = os.date("%z:%Z")
  local locale = os.setlocale(nil, "time")
  local presentation = entry.presentation
  if
    presentation
    and presentation.formatter == buffer_config.formatter
    and presentation.user_name == user_name
    and presentation.user_email == user_email
    and presentation.timezone == timezone
    and presentation.zone == zone
    and presentation.locale == locale
  then
    return presentation.lines
  end
  local labels = {} ---@type string[]
  for index, info in ipairs(entry.snapshot:commits()) do
    labels[index] = "    " .. (info.uncommitted and "Not committed yet" or format_blame(info, buffer_config.formatter))
  end
  local lines = entry.snapshot:annotations(labels)
  entry.presentation = {
    lines = lines,
    formatter = buffer_config.formatter,
    user_name = user_name,
    user_email = user_email,
    timezone = timezone,
    zone = zone,
    locale = locale,
  }
  return lines
end

---@type table<integer, boolean>
local buffer_enabled = {}

---@type table<integer, integer>
local buffer_current_lnum = {}

---@param bufnr                         integer
local function buffer_clear(bufnr)
  if vim.api.nvim_buf_is_valid(bufnr) then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, buffer_ns, 0, -1)
  end
end

---@param bufnr                         integer
---@param entry                         era.m.git.blame.ICacheEntry
---@param skip_lnum                     ?integer
---@return nil
local function buffer_render(bufnr, entry, skip_lnum)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  buffer_clear(bufnr)

  local annotations = buffer_annotations(entry)
  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  for lnum = 1, line_count do
    local text = annotations[lnum]
    if lnum ~= skip_lnum and text then
      pcall(vim.api.nvim_buf_set_extmark, bufnr, buffer_ns, lnum - 1, 0, {
        virt_text = { { text, buffer_config.hl_group } },
        virt_text_win_col = 80,
        priority = buffer_config.priority,
        hl_mode = "combine",
      })
    end
  end
end

---@param bufnr                         integer
---@return integer|nil
local function buffer_cursor_lnum(bufnr)
  local winnr = vim.fn.bufwinid(bufnr) ---@type integer
  if winnr == -1 then
    return nil
  end
  return vim.api.nvim_win_get_cursor(winnr)[1]
end

--- Render the overlay from the changedtick-valid cache, fetching blame when the
--- cache is missing or stale for the current content.
---@param bufnr                         integer
---@return nil
local function buffer_render_or_fetch(bufnr)
  if exiting or not buffer_enabled[bufnr] or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local buf_cache = era.m.git.buffer.get_cache(bufnr)
  if not buf_cache or buf_cache.untracked then
    buffer_clear(bufnr) -- untracked (or detached): drop any stale overlay annotations
    return
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer

  local entry = cache[bufnr]
  if entry and entry.tick == tick and entry.owner == buf_cache then
    local lnum = buffer_cursor_lnum(bufnr)
    buffer_current_lnum[bufnr] = lnum or 0
    buffer_render(bufnr, entry, lnum)
    return
  end

  -- Same content already failed; skip the re-run/re-report (see inline_update).
  local failed_entry = failed[bufnr] ---@type era.m.git.blame.IFailedEntry|nil
  if failed_entry and failed_entry.tick == tick and failed_entry.owner == buf_cache then
    return
  end

  local inflight = buffer_inflight[bufnr]
  if inflight and inflight.tick == tick and inflight.owner == buf_cache and not inflight.token:is_cancelled() then
    return
  end
  if inflight then
    inflight.token:cancel()
  end

  local token = stl.c.CancellationToken.new()
  buffer_inflight[bufnr] = { owner = buf_cache, token = token, tick = tick }

  run_blame(bufnr, buf_cache.relpath, buf_cache.repo.toplevel, token):finally(function(ok, result)
    local current = buffer_inflight[bufnr]
    if not current or current.token ~= token then
      return
    end
    buffer_inflight[bufnr] = nil

    if
      not buffer_enabled[bufnr]
      or not vim.api.nvim_buf_is_valid(bufnr)
      or vim.api.nvim_buf_get_changedtick(bufnr) ~= tick
      or era.m.git.buffer.get_cache(bufnr) ~= buf_cache
    then
      return
    end

    if not ok then
      if result ~= CANCELLED then -- never let a cancel poison the failure cache (see inline_update)
        failed[bufnr] = { owner = buf_cache, tick = tick }
      end
      report_failure(bufnr, result)
      return
    end

    failed[bufnr] = nil
    cache[bufnr] = { snapshot = result, owner = buf_cache, tick = tick }
    buffer_render_or_fetch(bufnr)
  end)
end

---@param bufnr                         integer
---@return nil
local function buffer_update_current_line(bufnr)
  if exiting or not buffer_enabled[bufnr] then
    return
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  local entry = cache[bufnr]
  if not entry or entry.tick ~= tick or entry.owner ~= era.m.git.buffer.get_cache(bufnr) then
    buffer_render_or_fetch(bufnr) -- stale/missing: re-blame against current content
    return
  end

  local lnum = buffer_cursor_lnum(bufnr)
  if not lnum or buffer_current_lnum[bufnr] == lnum then
    return
  end

  buffer_current_lnum[bufnr] = lnum
  buffer_render(bufnr, entry, lnum)
end

---@type stl.timer.IDisposableCallable
local buffer_update_debounced = stl.timer.debounce(function(bufnr)
  buffer_update_current_line(bufnr)
end, 50)

local function buffer_setup_autocmds()
  vim.api.nvim_clear_autocmds({ group = buffer_augroup })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = buffer_augroup,
    callback = function(args)
      buffer_update_debounced(args.buf)
    end,
  })
end

---@param bufnr                         integer|nil
function M.buffer_hide(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  buffer_enabled[bufnr] = nil
  buffer_current_lnum[bufnr] = nil
  local inflight = buffer_inflight[bufnr]
  if inflight then
    inflight.token:cancel()
  end
  buffer_clear(bufnr)
end

---@param bufnr                         integer|nil
function M.buffer_show(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if not era.m.git.buffer.get_cache(bufnr) then
    return
  end

  buffer_enabled[bufnr] = true
  buffer_render_or_fetch(bufnr)
end

---@param bufnr                         integer|nil
function M.buffer_toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if buffer_enabled[bufnr] then
    M.buffer_hide(bufnr)
  else
    M.buffer_show(bufnr)
  end
end

----------------------------------------------------------------------------------------------------
-- Invalidation (driven by writes and the repo watcher)
----------------------------------------------------------------------------------------------------

--- Drop a buffer's cached blame and repaint whatever is currently visible. Used
--- after a write (file content changed) or a HEAD move (committed blame changed),
--- neither of which bumps changedtick. Any in-flight run is cancelled first: it was
--- computed against the pre-invalidate content/HEAD, and because changedtick is
--- unchanged it would otherwise coalesce and backfill the cache with that stale
--- result, defeating the invalidate.
---@param bufnr                         integer
function M.invalidate(bufnr)
  cache[bufnr] = nil
  failed[bufnr] = nil -- content/HEAD changed: a previously-failed blame may now succeed

  local inline_run = inline_inflight[bufnr]
  if inline_run then
    inline_run.token:cancel()
  end
  local buffer_run = buffer_inflight[bufnr]
  if buffer_run then
    buffer_run.token:cancel()
  end

  inline_reset(bufnr)

  if buffer_enabled[bufnr] then
    buffer_render_or_fetch(bufnr)
  end

  -- Inline blame is current-line / current-window only (one shared debounce timer),
  -- so only the active buffer schedules an inline refresh here; other buffers repaint
  -- on their next CursorMoved.
  if inline_config.enabled and bufnr == vim.api.nvim_get_current_buf() and era.m.git.buffer.is_attached(bufnr) then
    inline_update_debounced(bufnr)
  end
end

---@return nil
function M.invalidate_all()
  -- Visit the UNION of buffers with a cache, an in-flight run, or enabled overlay
  -- blame - not just `cache`. A buffer whose first blame is still loading has no
  -- cache entry yet; if we skipped it, its pre-HEAD-move run would survive and
  -- backfill stale blame on the unchanged changedtick.
  local seen = {} ---@type table<integer, boolean>
  local bufs = {} ---@type integer[]
  local function add(bufnr)
    if not seen[bufnr] then
      seen[bufnr] = true
      bufs[#bufs + 1] = bufnr
    end
  end
  for bufnr in pairs(cache) do
    add(bufnr)
  end
  for bufnr in pairs(inline_inflight) do
    add(bufnr)
  end
  for bufnr in pairs(buffer_inflight) do
    add(bufnr)
  end
  for bufnr in pairs(buffer_enabled) do
    add(bufnr)
  end
  -- Also revisit buffers that ONLY hold a failed marker (no cache/inflight/overlay):
  -- otherwise a HEAD move can't clear the failure cache, which would suppress
  -- the post-move re-blame on the unchanged changedtick.
  for bufnr in pairs(failed) do
    add(bufnr)
  end

  for _, bufnr in ipairs(bufs) do
    M.invalidate(bufnr)
  end

  -- The active buffer may have nothing cached/in-flight yet but still wants a fresh annotation.
  local current = vim.api.nvim_get_current_buf() ---@type integer
  if not seen[current] and inline_config.enabled and era.m.git.buffer.is_attached(current) then
    inline_update_debounced(current)
  end
end

--- Drop ALL blame failure markers (the negative cache), without touching the
--- positive cache. Called on a git index change: an untracked file can become
--- blameable via `git add` / `git add -N` with NO buffer edit or HEAD move, so its
--- changedtick is unchanged and the negative cache would otherwise keep suppressing
--- a now-valid blame. Staging never changes blame attribution, so the positive
--- cache stays valid - clearing only failures avoids a needless re-blame/flicker.
---@return nil
function M.clear_failed()
  for bufnr in pairs(failed) do
    failed[bufnr] = nil
  end
end

---@type integer
local invalidate_augroup = vim.api.nvim_create_augroup("DotModuleGitBlameInvalidate", { clear = true })

function M.inline_toggle()
  inline_config.enabled = not inline_config.enabled
  inline_setup_autocmds()
  if not inline_config.enabled then
    local runs = {} ---@type era.m.git.blame.IInflight[]
    for _, run in pairs(inline_inflight) do
      runs[#runs + 1] = run
    end
    for _, run in ipairs(runs) do
      run.token:cancel()
    end
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      inline_reset(bufnr)
    end
  end
end

---@return nil
function M.setup()
  inline_setup_autocmds()
  buffer_setup_autocmds()

  -- Own augroup so an inline/buffer toggle (which clears their groups) never drops
  -- write-invalidation. After a write the on-disk file changed but changedtick did
  -- not, so the cache must be dropped explicitly.
  vim.api.nvim_clear_autocmds({ group = invalidate_augroup })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = invalidate_augroup,
    callback = function()
      exiting = true
      inline_update_debounced:dispose()
      buffer_update_debounced:dispose()
      for _, run in pairs(inline_inflight) do
        run.token:cancel()
      end
      for _, run in pairs(buffer_inflight) do
        run.token:cancel()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufWritePost", "BufFilePost" }, {
    group = invalidate_augroup,
    callback = function(args)
      M.invalidate(args.buf)
    end,
  })

  -- Complete per-buffer teardown on delete (cancels both inflights, drops all
  -- inline AND overlay state). Lives in the stable augroup so an inline toggle,
  -- which clears inline_augroup, can never drop it.
  vim.api.nvim_create_autocmd("BufDelete", {
    group = invalidate_augroup,
    callback = function(args)
      local bufnr = args.buf ---@type integer
      local inline_run = inline_inflight[bufnr]
      if inline_run then
        inline_run.token:cancel()
      end
      local buffer_run = buffer_inflight[bufnr]
      if buffer_run then
        buffer_run.token:cancel()
      end
      cache[bufnr] = nil
      failed[bufnr] = nil
      buffer_enabled[bufnr] = nil
      buffer_current_lnum[bufnr] = nil
    end,
  })
end

return M
