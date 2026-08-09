---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.state" ---@type string

---@class era.m.git.state
local M = {}

---@type stl.c.Observable<string>
M.o_branch = stl.c.Observable.from_value("")

---@type stl.c.Observable<integer>
M.o_refreshed = stl.c.Observable.from_value(0)

---@type stl.c.Observable<string[]>
M.o_ignored_refreshed = stl.c.Observable.from_value({})

---@type stl.c.Observable<string[]>
M.o_staged_files = stl.c.Observable.from_value({})

---@type stl.c.Observable<string[]>
M.o_unstaged_files = stl.c.Observable.from_value({})

---@type string|nil
local user_name = nil

---@type string|nil
local user_email = nil

local IGNORED_CACHE_CAPACITY = 2000 ---@type integer

---@type era.m.git.status.IAggregatedCache
local aggregated_cache = {
  dir_cache = {},
  file_display = {},
  file_stage = {},
  file_summary = {},
  staged_files = {},
  status_table = {},
  unstaged_files = {},
}

---@type table<string, boolean>
local ignored_cache = {}

---@type integer
local ignored_count = 0

---@type { gitignore: integer|nil, exclude: integer|nil }
local ignored_mtime = {
  gitignore = nil,
  exclude = nil,
}

---@type boolean
local ignored_mtime_initialized = false

---@type boolean
local initialized = false

---@type integer
local last_refresh = 0

---@type integer
local refresh_generation = 0

---@type boolean
local refreshing = false

local REFRESH_THROTTLE_MS = 800 ---@type integer

---@type boolean
local pending_refresh = false

---@type boolean
local pending_force = false

---@type (fun(): nil)[]
local queued_refresh_callbacks = {}

---@type stl.timer.IDisposableCallable
local refresh_throttled

local function run_queued_refresh_callbacks()
  local callbacks = queued_refresh_callbacks
  queued_refresh_callbacks = {}
  for _, callback in ipairs(callbacks) do
    callback()
  end
end

---@type stl.c.CancellationToken|nil
local current_collect_token = nil

local function do_refresh()
  if refreshing then
    pending_refresh = true
    return
  end

  local force = pending_force ---@type boolean
  pending_force = false
  pending_refresh = false
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

    if resolved and result and type(result.status_map) == "table" then
      local status_changed = not stl.fn.equals_deep(aggregated_cache.status_table, result.status_map) ---@type boolean
      if status_changed then
        local aggregated = era.m.git.status.aggregate(result.status_map)

        aggregated_cache.dir_cache = {}
        aggregated_cache.file_display = aggregated.file_display
        aggregated_cache.file_stage = aggregated.file_stage
        aggregated_cache.file_summary = aggregated.file_summary
        aggregated_cache.staged_files = aggregated.staged_files
        aggregated_cache.status_table = aggregated.status_table
        aggregated_cache.unstaged_files = aggregated.unstaged_files
      end

      initialized = true
      last_refresh = vim.uv.now()
      refresh_generation = refresh_generation + 1
      M.o_refreshed:next(refresh_generation)

      if status_changed then
        M.o_staged_files:next(aggregated_cache.staged_files)
        M.o_unstaged_files:next(aggregated_cache.unstaged_files)
      end
    elseif not token:is_cancelled() then
      local reason = tostring(result or "Unknown error"):match("^[^\r\n]+") or "Unknown error" ---@type string
      stl.reporter.error({
        from = __module_name__,
        subject = "refresh",
        message = "Failed to refresh Git status: " .. reason,
      })
    end

    refreshing = false
    run_queued_refresh_callbacks()

    if pending_refresh then
      refresh_throttled()
    end
  end)
end

refresh_throttled = stl.timer.throttle(do_refresh, REFRESH_THROTTLE_MS)

---@return era.m.git.status.IAggregatedCache
function M.aggregated()
  return aggregated_cache
end

function M.clear_ignored_cache()
  ignored_cache = {}
  ignored_count = 0
end

local function refresh_ignore_mtime()
  local workspace = dot.path.workspace() ---@type string
  local gitignore_path = dot.path.join(workspace, ".gitignore") ---@type string
  local exclude_path = dot.path.join(workspace, ".git/info/exclude") ---@type string

  ---@param path                        string
  ---@return integer|nil
  local function stat_mtime(path)
    local stat = vim.uv.fs_stat(path) ---@type uv.fs_stat.result|nil
    if stat and stat.mtime then
      return stat.mtime.sec
    end
    return nil
  end

  local gitignore_mtime = stat_mtime(gitignore_path) ---@type integer|nil
  local exclude_mtime = stat_mtime(exclude_path) ---@type integer|nil

  if ignored_mtime_initialized then
    if gitignore_mtime ~= ignored_mtime.gitignore or exclude_mtime ~= ignored_mtime.exclude then
      M.clear_ignored_cache()
    end
  end

  ignored_mtime.gitignore = gitignore_mtime
  ignored_mtime.exclude = exclude_mtime
  ignored_mtime_initialized = true
end

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

---@param filepath                   string
---@return boolean
function M.is_ignored(filepath)
  if not dot.path.is_git_repo() then
    return false
  end

  -- Strip any trailing slash: `git check-ignore` cannot resolve a directory symlink path
  -- ending in "/" ("fatal: ... is beyond a symbolic link"), and ignore status is
  -- slash-insensitive anyway. Keep the cache key consistent with __preload_ignored__.
  local normalized = dot.path.normalize(filepath, false)
  local cached = ignored_cache[normalized]
  if cached ~= nil then
    return cached
  end

  return false
end

---@return boolean
function M.is_initialized()
  return initialized
end

---@return integer
function M.last_refreshed_at()
  return last_refresh
end

---@param filepath                   string
---@param workspace                  string
---@param resolved_cache             table<string, string|false>
---@return string
local function __resolve_ignore_query_path__(filepath, workspace, resolved_cache)
  local prefix = workspace:sub(-1) == stl.env.PATH_SEP and workspace or (workspace .. stl.env.PATH_SEP) ---@type string
  if filepath ~= workspace and not vim.startswith(filepath, prefix) then
    return filepath
  end

  local current = filepath ---@type string
  local resolved = false ---@type string|false
  local visited = {} ---@type string[]
  while true do
    local cached = resolved_cache[current] ---@type string|false|nil
    if cached ~= nil then
      resolved = cached
      break
    end

    local stat = vim.uv.fs_lstat(current) ---@type uv.fs_stat.result|nil
    visited[#visited + 1] = current
    if stat ~= nil and stat.type == "link" then
      resolved = current
      break
    end
    if current == workspace then
      break
    end

    local parent = dot.path.dirname(current) ---@type string
    if parent == "" or parent == current then
      break
    end
    current = parent
  end

  for _, path in ipairs(visited) do
    resolved_cache[path] = resolved
  end
  return resolved or filepath
end

---@param filepaths                  string[]
---@param workspace                  string
---@param resolved_cache             table<string, string|false>
---@return table<string, string>     pending
---@return integer                   pending_count
---@return string[]                  query_paths
local function __build_ignore_pending__(filepaths, workspace, resolved_cache)
  local pending = {} ---@type table<string, string>
  local pending_count = 0 ---@type integer
  local query_paths = {} ---@type string[]
  local query_seen = {} ---@type table<string, boolean>

  for _, filepath in ipairs(filepaths) do
    local normalized = dot.path.normalize(filepath, false) ---@type string
    if ignored_cache[normalized] == nil and pending[normalized] == nil then
      local query_path = __resolve_ignore_query_path__(normalized, workspace, resolved_cache) ---@type string
      pending[normalized] = query_path
      pending_count = pending_count + 1
      if not query_seen[query_path] then
        query_seen[query_path] = true
        query_paths[#query_paths + 1] = query_path
      end
    end
  end

  return pending, pending_count, query_paths
end

---@param filepaths                  string[]
---@param callback                   ?(fun(): nil)
---@return fun(): nil                cancel_fn
local function __preload_ignored__(filepaths, callback)
  if not dot.path.is_git_repo() then
    if callback then
      callback()
    end
    return stl.fn.noop
  end

  refresh_ignore_mtime()

  local workspace = dot.path.normalize(dot.path.workspace(), false) ---@type string
  local resolved_cache = {} ---@type table<string, string|false>
  local pending, pending_count, query_paths = __build_ignore_pending__(filepaths, workspace, resolved_cache)

  if pending_count > 0 and ignored_count + pending_count > IGNORED_CACHE_CAPACITY then
    -- Clearing invalidates prior hits from this batch, so rebuild instead of querying only the
    -- keys that were pending before the reset. A fully cached batch must never trigger a reset.
    ignored_cache = {}
    ignored_count = 0
    pending, pending_count, query_paths = __build_ignore_pending__(filepaths, workspace, resolved_cache)
  end

  if pending_count == 0 then
    if callback then
      callback()
    end
    return stl.fn.noop
  end

  local input = table.concat(query_paths, "\n")

  local cancelled = false
  local proc = vim.system(
    { "git", "-C", workspace, "check-ignore", "--stdin" },
    { stdin = input, text = true },
    function(obj)
      if cancelled then
        return
      end
      vim.schedule(function()
        if cancelled then
          return
        end
        local ignored_set = {} ---@type table<string, boolean>
        local stdout = obj.stdout or ""
        for line in stdout:gmatch("[^\r\n]+") do
          ignored_set[dot.path.normalize(line, false)] = true
        end
        local completed = obj.code == 0 or obj.code == 1 ---@type boolean
        if not completed then
          stl.reporter.warn({
            from = __module_name__,
            subject = "preload_ignored",
            message = "git check-ignore failed",
            details = { code = obj.code, stderr = obj.stderr },
          })
        end

        local changed_filepaths = {} ---@type string[]
        -- A failed batch may not have consumed all stdin. Positive matches remain valid, but
        -- missing output is unknown and must not be persisted as "not ignored".
        for filepath, query_path in pairs(pending) do
          local ignored = ignored_set[query_path] == true ---@type boolean
          if ignored or completed then
            local current = ignored_cache[filepath] ---@type boolean|nil
            if current == nil then
              ignored_count = ignored_count + 1
              ignored_cache[filepath] = ignored
              if ignored then
                changed_filepaths[#changed_filepaths + 1] = filepath
              end
            elseif current ~= ignored then
              ignored_cache[filepath] = ignored
              changed_filepaths[#changed_filepaths + 1] = filepath
            end
          end
        end

        if #changed_filepaths > 0 then
          -- The same paths can change again after a cache reset; this observable carries events, not a snapshot.
          M.o_ignored_refreshed:next(changed_filepaths, { force = true })
        end

        if callback then
          callback()
        end
      end)
    end
  )

  return function()
    cancelled = true
    if proc then
      proc:kill(9)
    end
  end
end

---@param filepaths                  string[]
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with nil when preload completes
function M.preload_ignored(filepaths, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end
    local cancel_fn = __preload_ignored__(filepaths, function()
      resolve(nil)
    end)
    if token then
      token:on_cancel(cancel_fn)
    end
  end)
end

---@param force                      ?boolean
---@param callback                   ?(fun(): nil)
local function __refresh__(force, callback)
  if callback then
    queued_refresh_callbacks[#queued_refresh_callbacks + 1] = callback
  end

  if force then
    pending_force = true
  end

  refresh_throttled()
end

---Refresh git status (Future variant).
---Note: This operation uses internal throttling. The token only prevents waiting
---for resolution if cancelled before the call; it does not cancel the underlying
---throttled refresh operation which may be shared by multiple callers.
---@param force                      ?boolean
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with nil when refresh completes
function M.refresh(force, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end
    __refresh__(force, function()
      resolve(nil)
    end)
  end)
end

---@param base                       ?string
---@param token                      ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with table<string, string>; propagates collection failures
function M.status(base, token)
  if token and token:is_cancelled() then
    return stl.c.Future.resolve({})
  end

  return era.m.git.status.collect({ base = base }, token):map(function(collect_result)
    local result = {} ---@type table<string, string>
    if collect_result and type(collect_result.status_map) == "table" then
      for filepath, entry in pairs(collect_result.status_map) do
        if type(filepath) == "string" and type(entry) == "table" then
          result[filepath] = entry.display or ""
        end
      end
    end
    return result
  end)
end

---@return table<string, era.m.git.StatusEntry>
function M.status_table()
  return aggregated_cache.status_table
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

return M
