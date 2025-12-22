local DEBOUNCE_MS = 200

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

---@type fun()|nil
local on_change_callback = nil

local function trigger_change()
  if not debounce_timer then
    debounce_timer = vim.uv.new_timer()
  end

  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
      if on_change_callback then
        on_change_callback()
      end
    end))
  end
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
      trigger_change()
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
        trigger_change()
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
      M.update(r.gitdir)
      dot.git.state.refresh_async()
    end
  end)
end

local function on_git_change()
  dot.git.buffer.refresh_all()
  dot.git.state.refresh_async()
end

function M.dispose()
  stop_watcher()
  on_change_callback = nil
end

---@return string|nil
function M.get_gitdir()
  return current_gitdir
end

function M.setup()
  local augroup = vim.api.nvim_create_augroup("DotModuleGitWatcher", { clear = true }) ---@type integer

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      M.dispose()
    end,
  })

  on_change_callback = on_git_change
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
