---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.state" ---@type string

local ignore = require("era.m.git.ignore")

---@class era.m.git.state
local M = {}

---@type stl.c.Observable<string>
M.o_branch = stl.c.Observable.from_value("")

---@type stl.c.Observable<era.m.git.state.IRefreshEvent>
M.o_refreshed = stl.c.Observable.from_value({ change_scope = "unknown", generation = 0 })

---@type stl.c.Observable<string[]>
M.o_ignored_refreshed = ignore.o_refreshed

---@type stl.c.Observable<string[]>
M.o_staged_files = stl.c.Observable.from_value({})

---@type stl.c.Observable<string[]>
M.o_unstaged_files = stl.c.Observable.from_value({})

---@type string|nil
local user_name = nil

---@type string|nil
local user_email = nil

---@type yoz.git.StatusSnapshot
local current_snapshot = era.m.git.status.empty()

---@type boolean
local initialized = false

---@type integer
local last_refresh = 0

---@type integer
local refresh_generation = 0

---@type boolean
local refreshing = false

local exiting = false ---@type boolean

local REFRESH_THROTTLE_MS = 800 ---@type integer

---@type boolean
local pending_refresh = false

---@type boolean
local pending_force = false

---@type boolean
local pending_unknown_change = false

---@type (fun(): nil)[]
local queued_refresh_callbacks = {}

---@type stl.timer.IDisposableCallable
local refresh_throttled

---@return nil
local function run_queued_refresh_callbacks()
  local callbacks = queued_refresh_callbacks
  queued_refresh_callbacks = {}
  for _, callback in ipairs(callbacks) do
    callback()
  end
end

---@type stl.c.CancellationToken|nil
local current_collect_token = nil

---@return nil
local function do_refresh()
  if exiting then
    return
  end
  if refreshing then
    pending_refresh = true
    return
  end

  local force = pending_force ---@type boolean
  local change_scope = pending_unknown_change and "unknown" or "index" ---@type era.m.git.StatusChangeScope
  pending_force = false
  pending_refresh = false
  pending_unknown_change = false
  refreshing = true

  if force then
    initialized = false
  end

  if current_collect_token then
    current_collect_token:cancel()
    current_collect_token = nil
  end

  local token = stl.c.CancellationToken.new()
  current_collect_token = token

  era.m.git.status.collect(nil, token):finally(function(resolved, result)
    current_collect_token = nil

    if resolved and result and not exiting and not token:is_cancelled() then
      local status_changed = not current_snapshot:equals(result) ---@type boolean
      if status_changed then
        current_snapshot = result
      end

      initialized = true
      last_refresh = vim.uv.now()
      refresh_generation = refresh_generation + 1
      M.o_refreshed:next({ change_scope = change_scope, generation = refresh_generation })

      if status_changed then
        local staged, unstaged = current_snapshot:changed_files()
        M.o_staged_files:next(staged)
        M.o_unstaged_files:next(unstaged)
      end
    elseif not exiting and not token:is_cancelled() then
      local reason = tostring(result or "Unknown error"):match("^[^\r\n]+") or "Unknown error" ---@type string
      stl.reporter.error({
        from = __module_name__,
        subject = "refresh",
        message = "Failed to refresh Git status: " .. reason,
      })
    end

    refreshing = false
    run_queued_refresh_callbacks()

    if pending_refresh and not exiting then
      refresh_throttled()
    end
  end)
end

refresh_throttled = stl.timer.throttle(do_refresh, REFRESH_THROTTLE_MS)

---@return yoz.git.StatusSnapshot
function M.snapshot()
  return current_snapshot
end

M.clear_ignored_cache = ignore.clear
M.is_ignored = ignore.is_ignored
M.preload_ignored = ignore.preload

---@return string
function M.get_branch()
  return M.o_branch:snapshot()
end

---@return string|nil
function M.get_user_email()
  return user_email
end

---@return string|nil
function M.get_user_name()
  return user_name
end

---@return boolean
function M.is_initialized()
  return initialized
end

---@return integer
function M.last_refreshed_at()
  return last_refresh
end

---@param force                      ?boolean
---@param callback                   ?(fun(): nil)
---@param change_scope               ?era.m.git.StatusChangeScope
local function __refresh__(force, callback, change_scope)
  if callback then
    queued_refresh_callbacks[#queued_refresh_callbacks + 1] = callback
  end

  if force then
    pending_force = true
  end
  -- Only an exclusively index-triggered collection can be compared with raw blob identities.
  -- Any coalesced request with broader or unknown provenance keeps the published event conservative.
  if change_scope ~= "index" then
    pending_unknown_change = true
  end

  refresh_throttled()
end

---@param force                         ?boolean
---@param token                         ?stl.c.CancellationToken
---@param change_scope                  era.m.git.StatusChangeScope
---@return stl.c.Future                 Resolves with nil when refresh completes
local function refresh(force, token, change_scope)
  return stl.c.Future.new(function(resolve)
    if exiting or (token and token:is_cancelled()) then
      resolve(nil)
      return
    end
    __refresh__(force, function()
      resolve(nil)
    end, change_scope)
  end)
end

---Refresh git status (Future variant).
---Note: This operation uses internal throttling. The token only prevents waiting
---for resolution if cancelled before the call; it does not cancel the underlying
---throttled refresh operation which may be shared by multiple callers.
---@param force                      ?boolean
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with nil when refresh completes
function M.refresh(force, token)
  return refresh(force, token, "unknown")
end

---Refresh after a known Git index mutation, allowing consumers to compare blob identities.
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with nil when refresh completes
function M.refresh_index(token)
  return refresh(false, token, "index")
end

---@param base                          ?string
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with table<string, string>; propagates collection failures
function M.status(base, token)
  if token and token:is_cancelled() then
    return stl.c.Future.resolve({})
  end

  return era.m.git.status.collect({ base = base }, token):map(function(collect_result)
    return collect_result:display()
  end)
end

---@return table<string, era.m.git.StatusEntry>
function M.status_table()
  return current_snapshot:entries()
end

function M.refresh_user_info()
  if not dot.path.is_git_repo() then
    return
  end

  local workspace = dot.path.workspace() ---@type string
  stl.git.exec.exec({ "config", "user.name" }, { cwd = workspace }):finally(function(resolved, result)
    if resolved and result and result.lines and #result.lines > 0 then
      user_name = result.lines[1]
    end
  end)
  stl.git.exec.exec({ "config", "user.email" }, { cwd = workspace }):finally(function(resolved, result)
    if resolved and result and result.lines and #result.lines > 0 then
      user_email = result.lines[1]
    end
  end)
end

---@return nil
function M.setup()
  local augroup = vim.api.nvim_create_augroup("DotModuleGitState", { clear = true }) ---@type integer

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      exiting = true
      pending_refresh = false
      refresh_throttled:dispose()
      if current_collect_token then
        current_collect_token:cancel()
      end
      run_queued_refresh_callbacks()
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    pattern = { ".gitignore", "*/.gitignore", "*/.git/info/exclude" },
    callback = M.clear_ignored_cache,
  })

  -- External ignore edits are not observable through buffer events. Focus is a
  -- cheap lifecycle boundary at which stale negative entries can be discarded.
  vim.api.nvim_create_autocmd("FocusGained", {
    group = augroup,
    callback = M.clear_ignored_cache,
  })
end

return M
