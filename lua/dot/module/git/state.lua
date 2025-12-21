---@class dot.module.git.state
local M = {}

---@type ark.c.Observable<string>
M.o_branch = ark.c.Observable.from_value("")

---@type ark.c.Observable<dot.module.git.BlameInfo|nil>
M.o_current_blame = ark.c.Observable.from_value(nil)

---@type ark.c.Observable<string[]>
M.o_staged_files = ark.c.Observable.from_value({})

---@type ark.c.Observable<string[]>
M.o_unstaged_files = ark.c.Observable.from_value({})

---@type dot.module.git.state.ICache
local state_cache = {
  dir_codes = {},
  dir_display = {},
  dir_stage = {},
  dir_summary = {},
  file_display = {},
  file_stage = {},
  file_summary = {},
  ignored = {},
  initialized = false,
  last_refresh = 0,
  status_table = {},
  workspace = nil,
}

---@type boolean
local refreshing = false

local function on_git_change()
  dot.git.buffer.refresh_all()
  M.refresh_async()
end

---@return dot.module.git.state.ICache
function M.cache()
  if not state_cache.initialized then
    M.refresh_async()
  end
  return state_cache
end

function M.clear_ignored_cache()
  state_cache.ignored = {}
end

---@return string
function M.get_branch()
  return M.o_branch:snapshot()
end

---@return dot.module.git.BlameInfo|nil
function M.get_current_blame()
  return M.o_current_blame:snapshot()
end

---@param filepath                   string
---@return boolean
function M.is_ignored(filepath)
  if not dot.path.is_git_repo() then
    return false
  end

  local normalized = dot.path.normalize(filepath)
  local cached = state_cache.ignored[normalized]
  if cached ~= nil then
    return cached
  end

  local is_ignored = dot.path.is_git_ignored(normalized)
  state_cache.ignored[normalized] = is_ignored
  return is_ignored
end

---@return integer
function M.last_refreshed_at()
  if not state_cache.initialized then
    M.refresh_async()
  end
  return state_cache.last_refresh
end

---@param filepaths                  string[]
function M.preload_ignored(filepaths)
  if not dot.path.is_git_repo() then
    return
  end

  local uncached = {}
  for _, filepath in ipairs(filepaths) do
    local normalized = dot.path.normalize(filepath)
    if state_cache.ignored[normalized] == nil then
      uncached[#uncached + 1] = normalized
    end
  end

  if #uncached == 0 then
    return
  end

  local input = table.concat(uncached, "\n")
  local result = vim.fn.system({ "git", "check-ignore", "--stdin" }, input)

  local ignored_set = {}
  if vim.v.shell_error == 0 or vim.v.shell_error == 1 then
    for line in result:gmatch("[^\r\n]+") do
      ignored_set[dot.path.normalize(line)] = true
    end
  end

  for _, fp in ipairs(uncached) do
    state_cache.ignored[fp] = ignored_set[fp] == true
  end
end

---@param force                      boolean|nil
---@param callback                   fun()|nil
function M.refresh_async(force, callback)
  if refreshing then
    if callback then
      callback()
    end
    return
  end

  if force then
    state_cache.initialized = false
  end

  refreshing = true
  dot.git.status.collect_async({ base = "HEAD" }, function(workspace, status_table)
    if type(status_table) == "table" then
      local aggregated = dot.git.status.aggregate(workspace, status_table)

      state_cache.dir_codes = aggregated.dir_codes
      state_cache.dir_display = aggregated.dir_display
      state_cache.dir_stage = aggregated.dir_stage
      state_cache.dir_summary = aggregated.dir_summary
      state_cache.file_display = aggregated.file_display
      state_cache.file_stage = aggregated.file_stage
      state_cache.file_summary = aggregated.file_summary
      state_cache.initialized = true
      state_cache.last_refresh = vim.uv.now()
      state_cache.status_table = aggregated.status_table
      state_cache.workspace = workspace and dot.path.normalize(workspace) or nil

      M.o_staged_files:next(aggregated.staged_files)
      M.o_unstaged_files:next(aggregated.unstaged_files)
    end

    refreshing = false
    if callback then
      callback()
    end
  end)
end

---@param base                       string|nil
---@param callback                   fun(workspace: string, result: table<string, string>)
function M.status_async(base, callback)
  dot.git.status.collect_async({ base = base }, function(workspace, status_table_result)
    local result = {}
    if type(status_table_result) == "table" then
      for filepath, entry in pairs(status_table_result) do
        if type(filepath) == "string" and type(entry) == "table" then
          result[filepath] = entry.display or ""
        end
      end
    end
    callback(workspace, result)
  end)
end

---@return table<string, dot.module.git.StatusEntry>
function M.status_table()
  if not state_cache.initialized then
    M.refresh_async()
  end
  return state_cache.status_table
end

dot.git.watcher.setup(on_git_change)

return M
