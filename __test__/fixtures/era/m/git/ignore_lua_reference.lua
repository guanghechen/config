--- Frozen pre-native ignore implementation: differential oracle only.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.git.ignore_lua_reference"
local M = {}
M.o_ignored_refreshed = stl.c.Observable.from_value({})
local IGNORED_CACHE_CAPACITY = 2000
local ignored_cache = {}
local ignored_count = 0
local ignored_generation = 0
local ignored_mtime = { gitignore = nil, exclude = nil }
local ignored_mtime_initialized = false

---@return nil
function M.clear_ignored_cache()
  ignored_cache = {}
  ignored_count = 0
  ignored_generation = ignored_generation + 1
end

---@return nil
local function refresh_ignore_mtime()
  local workspace = dot.path.workspace() ---@type string
  local gitignore_path = dot.path.join(workspace, ".gitignore") ---@type string
  local exclude_path = dot.path.join(workspace, ".git/info/exclude") ---@type string

  ---@param path                        string
  ---@return string|nil
  local function stat_mtime(path)
    local stat = vim.uv.fs_stat(path) ---@type uv.fs_stat.result|nil
    if stat and stat.mtime then
      return string.format("%d:%d", stat.mtime.sec or 0, stat.mtime.nsec or 0)
    end
    return nil
  end

  local gitignore_mtime = stat_mtime(gitignore_path) ---@type string|nil
  local exclude_mtime = stat_mtime(exclude_path) ---@type string|nil

  if ignored_mtime_initialized then
    if gitignore_mtime ~= ignored_mtime.gitignore or exclude_mtime ~= ignored_mtime.exclude then
      M.clear_ignored_cache()
    end
  end

  ignored_mtime.gitignore = gitignore_mtime
  ignored_mtime.exclude = exclude_mtime
  ignored_mtime_initialized = true
end


---@param filepath                      string
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


---@param filepath                      string
---@param workspace                     string
---@param resolved_cache                table<string, string|false>
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

---@param filepaths                     string[]
---@param workspace                     string
---@param resolved_cache                table<string, string|false>
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

---@param filepaths                     string[]
---@param callback                      ?fun(stale: boolean): nil
---@return fun(): nil                cancel_fn
local function __preload_ignored__(filepaths, callback)
  if not dot.path.is_git_repo() then
    if callback then
      callback(false)
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
    M.clear_ignored_cache()
    pending, pending_count, query_paths = __build_ignore_pending__(filepaths, workspace, resolved_cache)
  end

  if pending_count == 0 then
    if callback then
      callback(false)
    end
    return stl.fn.noop
  end

  local generation = ignored_generation ---@type integer
  local input = table.concat(query_paths, "\0") .. "\0"

  local cancelled = false
  local proc = vim.system(
    { "git", "-C", workspace, "check-ignore", "--stdin", "-z" },
    { stdin = input, text = false },
    function(obj)
      if cancelled then
        return
      end
      vim.schedule(function()
        if cancelled then
          return
        end
        if generation ~= ignored_generation then
          if callback then
            callback(true)
          end
          return
        end
        local ignored_set = {} ---@type table<string, boolean>
        local stdout = obj.stdout or ""
        for filepath in stdout:gmatch("([^%z]+)%z") do
          ignored_set[dot.path.normalize(filepath, false)] = true
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
          callback(false)
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

---@param filepaths                     string[]
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future              Resolves with nil when preload completes
function M.preload_ignored(filepaths, token)
  return stl.c.Future.new(function(resolve)
    if token and token:is_cancelled() then
      resolve(nil)
      return
    end

    local settled = false ---@type boolean
    local cancel_current = stl.fn.noop ---@type fun(): nil
    local cancellation = nil ---@type stl.c.IUnsubscribable|nil

    ---@return nil
    local function finish()
      if settled then
        return
      end
      settled = true
      if cancellation then
        cancellation:unsubscribe()
        cancellation = nil
      end
      resolve(nil)
    end

    local run ---@type fun(): nil
    run = function()
      if settled then
        return
      end
      cancel_current = __preload_ignored__(filepaths, function(stale)
        if stale then
          run()
        else
          finish()
        end
      end)
    end

    run()
    if token and not settled then
      cancellation = token:on_cancel(function()
        cancel_current()
        finish()
      end)
    end
  end)
end


return M
