---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.state" ---@type string

---@class era.m.git.state
local M = {}

---@type stl.c.Observable<string>
M.o_branch = stl.c.Observable.from_value("")

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

---@type boolean
local refreshing = false

local REFRESH_THROTTLE_MS = 800 ---@type integer

---@type boolean
local pending_refresh = false

---@type boolean
local pending_force = false

---@type (fun(): nil)[]
local queued_callbacks = {}

---@type stl.timer.IDisposableCallable
local refresh_throttled

local function run_queued_callbacks()
  local callbacks = queued_callbacks
  queued_callbacks = {}
  for _, callback in ipairs(callbacks) do
    callback()
  end
end

---@type (fun(): nil)|nil
local current_collect_cancel = nil

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

  if current_collect_cancel then
    current_collect_cancel()
    current_collect_cancel = nil
  end

  current_collect_cancel = era.m.git.status.collect_async({ base = "HEAD" }, function(status_table)
    current_collect_cancel = nil

    if type(status_table) == "table" then
      local aggregated = era.m.git.status.aggregate(status_table)

      aggregated_cache.dir_cache = {}
      aggregated_cache.file_display = aggregated.file_display
      aggregated_cache.file_stage = aggregated.file_stage
      aggregated_cache.file_summary = aggregated.file_summary
      aggregated_cache.staged_files = aggregated.staged_files
      aggregated_cache.status_table = aggregated.status_table
      aggregated_cache.unstaged_files = aggregated.unstaged_files

      initialized = true
      last_refresh = vim.uv.now()

      M.o_staged_files:next(aggregated.staged_files)
      M.o_unstaged_files:next(aggregated.unstaged_files)
    end

    refreshing = false
    run_queued_callbacks()

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

  local normalized = dot.path.normalize(filepath)
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

---@param filepaths                  string[]
---@param callback                   (fun(): nil)|nil
function M.preload_ignored(filepaths, callback)
  if not dot.path.is_git_repo() then
    if callback then
      callback()
    end
    return
  end

  local uncached = {} ---@type string[]
  for _, filepath in ipairs(filepaths) do
    local normalized = dot.path.normalize(filepath)
    if ignored_cache[normalized] == nil then
      uncached[#uncached + 1] = normalized
    end
  end

  refresh_ignore_mtime()

  if #uncached == 0 then
    if callback then
      callback()
    end
    return
  end

  if ignored_count + #uncached > IGNORED_CACHE_CAPACITY then
    ignored_cache = {}
    ignored_count = 0
  end

  local input = table.concat(uncached, "\n")
  local workspace = dot.path.workspace() ---@type string

  vim.system({ "git", "-C", workspace, "check-ignore", "--stdin" }, { stdin = input, text = true }, function(obj)
    vim.schedule(function()
      local ignored_set = {} ---@type table<string, boolean>
      if obj.code == 0 or obj.code == 1 then
        local stdout = obj.stdout or ""
        for line in stdout:gmatch("[^\r\n]+") do
          ignored_set[dot.path.normalize(line)] = true
        end
      elseif obj.code ~= 128 then
        stl.reporter.warn({
          from = "era.m.git.state",
          subject = "preload_ignored",
          message = "git check-ignore failed",
          details = { code = obj.code, stderr = obj.stderr },
        })
      end

      for _, fp in ipairs(uncached) do
        ignored_cache[fp] = ignored_set[fp] == true
        ignored_count = ignored_count + 1
      end

      if callback then
        callback()
      end
    end)
  end)
end

---@param force                      boolean|nil
---@param callback                   (fun(): nil)|nil
function M.refresh_async(force, callback)
  if callback then
    queued_callbacks[#queued_callbacks + 1] = callback
  end

  if force then
    pending_force = true
  end

  refresh_throttled()
end

---@param base                       string|nil
---@param callback                   fun(result: table<string, string>): nil
---@return fun(): nil                cancel_fn
function M.status_async(base, callback)
  return era.m.git.status.collect_async({ base = base }, function(status_table_result)
    local result = {}
    if type(status_table_result) == "table" then
      for filepath, entry in pairs(status_table_result) do
        if type(filepath) == "string" and type(entry) == "table" then
          result[filepath] = entry.display or ""
        end
      end
    end
    callback(result)
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
  stl.git.exec.exec_async({ "config", "user.name" }, { cwd = workspace }, function(lines)
    if #lines > 0 then
      user_name = lines[1]
    end
  end)
  stl.git.exec.exec_async({ "config", "user.email" }, { cwd = workspace }, function(lines)
    if #lines > 0 then
      user_email = lines[1]
    end
  end)
end

return M
