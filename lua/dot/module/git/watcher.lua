local DEBOUNCE_MS = 200 ---@type integer

---@class dot.module.git.watcher
local M = {}

---@type uv.uv_fs_event_t|nil
local fs_watcher_dir = nil

---@type uv.uv_fs_event_t|nil
local fs_watcher_index = nil

---@type uv.uv_timer_t|nil
local debounce_timer = nil

---@type string|nil
local current_gitdir = nil

---@type boolean
local pending_force = false

---@type boolean
local pending_branch_refresh = false

---@type boolean
local pending_index_only = false

---@type boolean
local pending_status = false

---@type string[]
local IGNORE_FILENAMES = {
  "COMMIT_EDITMSG",
  "MERGE_MSG",
  "ORIG_HEAD",
  "FETCH_HEAD",
  "REBASE_HEAD",
  "sequencer",
  "logs",
}

---@type string[]
local FORCE_REFRESH_FILENAMES = {
  "HEAD",
  "refs",
  "packed-refs",
}

---@type string[]
local BRANCH_REFRESH_FILENAMES = {
  "HEAD",
  "refs",
}

---@param filename                   string
---@return boolean
local function should_ignore(filename)
  for _, name in ipairs(IGNORE_FILENAMES) do
    if filename == name or vim.startswith(filename, name .. "/") then
      return true
    end
  end
  return false
end

---@param filename                   string
---@return boolean
local function should_force_refresh(filename)
  for _, name in ipairs(FORCE_REFRESH_FILENAMES) do
    if filename == name or vim.startswith(filename, name .. "/") then
      return true
    end
  end
  return false
end

---@param filename                   string
---@return boolean
local function should_refresh_branch(filename)
  for _, name in ipairs(BRANCH_REFRESH_FILENAMES) do
    if filename == name or vim.startswith(filename, name .. "/") then
      return true
    end
  end
  return false
end

local function refresh_branch()
  local r = dot.git.buffer.get_repo()
  if not r then
    return
  end

  dot.git.cmd.get_abbrev_head_async(r.toplevel, function(abbrev_head)
    if not r then
      return
    end
    r.abbrev_head = abbrev_head
    dot.git.state.o_branch:next(abbrev_head)
    dot.git.state.refresh_user_info()
  end)
end

local function trigger_refresh()
  if not debounce_timer then
    debounce_timer = vim.uv.new_timer()
  end

  if not debounce_timer then
    return
  end

  debounce_timer:stop()
  debounce_timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    local do_force = pending_force ---@type boolean
    local do_branch = pending_branch_refresh ---@type boolean
    local index_only = pending_index_only ---@type boolean
    local do_status = pending_status ---@type boolean

    pending_force = false
    pending_branch_refresh = false
    pending_index_only = false
    pending_status = false

    if do_branch then
      refresh_branch()
    end

    if index_only and not do_force and not do_status then
      dot.git.buffer.invalidate_index_all()
      dot.git.state.refresh_async(false)
    elseif do_force then
      dot.git.buffer.invalidate_compare_text_all()
      dot.git.state.refresh_async(true)
    elseif do_status then
      dot.git.buffer.mark_dirty_all()
      dot.git.state.refresh_async(false)
    end
  end))
end

---@param filename                   string
local function on_fs_event(filename)
  if should_ignore(filename) then
    return
  end

  pending_status = true

  if should_force_refresh(filename) then
    pending_force = true
    dot.git.state.clear_ignored_cache()
  end

  if should_refresh_branch(filename) then
    pending_branch_refresh = true
  end

  trigger_refresh()
end

local function on_index_event()
  pending_index_only = true
  trigger_refresh()
end

local function stop_watcher()
  if debounce_timer and not debounce_timer:is_closing() then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end

  if fs_watcher_dir and not fs_watcher_dir:is_closing() then
    fs_watcher_dir:stop()
    fs_watcher_dir:close()
    fs_watcher_dir = nil
  end

  if fs_watcher_index and not fs_watcher_index:is_closing() then
    fs_watcher_index:stop()
    fs_watcher_index:close()
    fs_watcher_index = nil
  end

  current_gitdir = nil
end

---@param gitdir                     string
local function start_watcher(gitdir)
  if current_gitdir == gitdir then
    return
  end

  stop_watcher()
  current_gitdir = gitdir

  fs_watcher_dir = vim.uv.new_fs_event()
  if fs_watcher_dir then
    fs_watcher_dir:start(gitdir, {}, function(err, filename)
      if err or not filename then
        return
      end
      if vim.startswith(filename, "index.lock") or vim.startswith(filename, ".watchman-cookie") then
        return
      end
      on_fs_event(filename)
    end)
  end

  local index_path = gitdir .. "/index"
  if vim.uv.fs_stat(index_path) then
    fs_watcher_index = vim.uv.new_fs_event()
    if fs_watcher_index then
      fs_watcher_index:start(index_path, {}, function(err)
        if err then
          return
        end
        on_index_event()
      end)
    end
  end
end

local function init_watcher()
  if not dot.path.is_git_repo() then
    return
  end

  local workspace = dot.path.workspace() ---@type string
  dot.git.repo.new(workspace, function(r)
    if r then
      dot.git.state.o_branch:next(r.abbrev_head)
      dot.git.state.refresh_user_info()
      M.update(r.gitdir)
      dot.git.state.refresh_async()
    end
  end)
end

function M.dispose()
  stop_watcher()
end

function M.setup()
  local augroup = vim.api.nvim_create_augroup("DotModuleGitWatcher", { clear = true }) ---@type integer

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      M.dispose()
    end,
  })

  vim.schedule(init_watcher)
end

---@param gitdir                     string|nil
function M.update(gitdir)
  if gitdir then
    start_watcher(gitdir)
  else
    stop_watcher()
  end
end

return M
