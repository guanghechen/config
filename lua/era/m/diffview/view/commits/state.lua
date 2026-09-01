---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.commits.state" ---@type string

local config = require("era.m.diffview.config")

---Commits view state management (for Git Log).
---@class era.m.diffview.view.commits.state
local M = {}

----------------------------------------------------------------------------------------------------
-- State class
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.commits.State
---@field public tabnr                   integer
---@field public fold_unchanged          boolean                         Current diff fold policy
---@field public commits                 stl.c.Observable                Observable<era.m.diffview.ICommit[]>
---@field public current_commit          stl.c.Observable                Observable<era.m.diffview.ICommit|nil>
---@field public current_entry           stl.c.Observable                Observable<era.m.diffview.IFileEntry|nil>
---@field public expanded_commits        stl.c.Observable                Observable<table<string, boolean>>
---@field public commits_page            stl.c.Observable                Observable<integer> (1-indexed)
---@field public commits_total           stl.c.Observable                Observable<integer>
---@field public lnum_present            stl.c.Observable                Observable<integer> line of currently displayed commit
---@field public collapsed_dirs          table<string, boolean>          Collapsed directory paths (for filetree in expanded commits)
---@field public path_filter             string|nil                      Path filter (file or directory path)
---@field protected _git_subscription    stl.c.IUnsubscribable|nil
---@field protected _git_debounce        stl.timer.IDisposableCallable|nil
---@field protected _tab_closed_autocmd  integer|nil
---@field protected _scheduler_lnum_present stl.c.Scheduler|nil
local State = {}
State.__index = State

---Create a new commits state instance
---@param tabnr                          integer
---@param fold_unchanged                 boolean
---@return era.m.diffview.view.commits.State
function State.new(tabnr, fold_unchanged)
  local self = setmetatable({}, State)

  self.tabnr = tabnr
  self.fold_unchanged = fold_unchanged

  self.commits = stl.c.Observable.from_value({})
  self.current_commit = stl.c.Observable.from_value(nil)
  self.current_entry = stl.c.Observable.from_value(nil)
  self.expanded_commits = stl.c.Observable.from_value({})

  -- Pagination state
  self.commits_page = stl.c.Observable.from_value(1)
  self.commits_total = stl.c.Observable.from_value(0)

  -- Sign state
  self.lnum_present = stl.c.Observable.from_value(-1)

  self.collapsed_dirs = {}
  self.path_filter = nil

  self._git_subscription = nil
  self._git_debounce = nil
  self._tab_closed_autocmd = nil
  self._scheduler_lnum_present = nil

  return self
end

----------------------------------------------------------------------------------------------------
-- Commit management
----------------------------------------------------------------------------------------------------

---Get commits snapshot
---@return era.m.diffview.ICommit[]
function State:get_commits()
  return self.commits:snapshot()
end

---Set commits
---@param commits                        era.m.diffview.ICommit[]
function State:set_commits(commits)
  self.commits:next(commits)
end

---Get current commit snapshot
---@return era.m.diffview.ICommit|nil
function State:get_current_commit()
  return self.current_commit:snapshot()
end

---Set current commit
---@param commit                         era.m.diffview.ICommit|nil
function State:set_current_commit(commit)
  self.current_commit:next(commit)
end

---Get current entry snapshot
---@return era.m.diffview.IFileEntry|nil
function State:get_current_entry()
  return self.current_entry:snapshot()
end

---Set current entry
---@param entry                          era.m.diffview.IFileEntry|nil
function State:set_current_entry(entry)
  self.current_entry:next(entry)
end

---Whether unchanged diff hunks are folded in this view.
---@return boolean
function State:get_fold_unchanged()
  return self.fold_unchanged
end

---Set whether unchanged diff hunks are folded in this view.
---@param fold_unchanged                 boolean
function State:set_fold_unchanged(fold_unchanged)
  self.fold_unchanged = fold_unchanged
end

----------------------------------------------------------------------------------------------------
-- Commit expansion management
----------------------------------------------------------------------------------------------------

---Toggle commit expansion
---@param hash                           string
function State:toggle_commit_expanded(hash)
  local expanded = vim.tbl_extend("force", {}, self.expanded_commits:snapshot())
  expanded[hash] = not expanded[hash]
  self.expanded_commits:next(expanded)
end

---Check if commit is expanded
---@param hash                           string
---@return boolean
function State:is_commit_expanded(hash)
  return self.expanded_commits:snapshot()[hash] == true
end

---Expand commit
---@param hash                           string
function State:expand_commit(hash)
  if not self:is_commit_expanded(hash) then
    self:toggle_commit_expanded(hash)
  end
end

---Collapse commit
---@param hash                           string
function State:collapse_commit(hash)
  if self:is_commit_expanded(hash) then
    self:toggle_commit_expanded(hash)
  end
end

---Expand all commits
function State:expand_all()
  local commits = self:get_commits()
  local expanded = {} ---@type table<string, boolean>
  for _, commit in ipairs(commits) do
    expanded[commit.hash] = true
  end
  self.expanded_commits:next(expanded)
end

---Collapse all commits
function State:collapse_all()
  self.expanded_commits:next({})
end

---Get expanded commits snapshot
---@return table<string, boolean>
function State:get_expanded_commits()
  return vim.tbl_extend("force", {}, self.expanded_commits:snapshot())
end

----------------------------------------------------------------------------------------------------
-- Pagination management
----------------------------------------------------------------------------------------------------

---Get current page (1-indexed)
---@return integer
function State:get_commits_page()
  return self.commits_page:snapshot()
end

---Set current page
---@param page                           integer
function State:set_commits_page(page)
  self.commits_page:next(page)
end

---Get total commit count
---@return integer
function State:get_commits_total()
  return self.commits_total:snapshot()
end

---Set total commit count
---@param total                          integer
function State:set_commits_total(total)
  self.commits_total:next(total)
end

---Get total page count
---@return integer
function State:get_commits_page_count()
  local total = self:get_commits_total()
  local per_page = config.COMMITS_PER_PAGE
  return math.max(1, math.ceil(total / per_page))
end

---Has next page
---@return boolean
function State:has_next_page()
  return self:get_commits_page() < self:get_commits_page_count()
end

---Has previous page
---@return boolean
function State:has_prev_page()
  return self:get_commits_page() > 1
end

----------------------------------------------------------------------------------------------------
-- Directory collapse management (for filetree in expanded commits)
----------------------------------------------------------------------------------------------------

---Check if directory is collapsed
---@param dir_path                       string
---@return boolean
function State:is_collapsed(dir_path)
  return self.collapsed_dirs[dir_path] == true
end

---Toggle directory collapse state
---@param dir_path                       string
function State:toggle_collapse(dir_path)
  self.collapsed_dirs[dir_path] = not self.collapsed_dirs[dir_path]
end

---Expand directory
---@param dir_path                       string
function State:expand_dir(dir_path)
  self.collapsed_dirs[dir_path] = nil
end

---Collapse directory
---@param dir_path                       string
function State:collapse_dir(dir_path)
  self.collapsed_dirs[dir_path] = true
end

---Get collapsed dirs snapshot
---@return table<string, boolean>
function State:get_collapsed_dirs()
  return vim.tbl_extend("force", {}, self.collapsed_dirs)
end

---Set collapsed dirs
---@param collapsed_dirs                 table<string, boolean>
function State:set_collapsed_dirs(collapsed_dirs)
  self.collapsed_dirs = collapsed_dirs
end

----------------------------------------------------------------------------------------------------
-- Path filter management
----------------------------------------------------------------------------------------------------

---Get path filter
---@return string|nil
function State:get_path_filter()
  return self.path_filter
end

---Set path filter
---@param path                           string|nil
function State:set_path_filter(path)
  self.path_filter = path
end

----------------------------------------------------------------------------------------------------
-- Sign line management
----------------------------------------------------------------------------------------------------

---Get present line number (line of currently displayed commit)
---@return integer
function State:get_lnum_present()
  return self.lnum_present:snapshot()
end

---Set present line number
---@param lnum                           integer
function State:set_lnum_present(lnum)
  self.lnum_present:next(lnum)
end

---Set sign scheduler
---@param scheduler_present              stl.c.Scheduler
function State:set_sign_scheduler(scheduler_present)
  self._scheduler_lnum_present = scheduler_present
end

---Schedule present sign update
function State:schedule_sign_present()
  if self._scheduler_lnum_present then
    self._scheduler_lnum_present:schedule()
  end
end

----------------------------------------------------------------------------------------------------
-- Subscriptions
----------------------------------------------------------------------------------------------------

---Subscribe to observable field changes
---@param field                          "commits"|"current_commit"|"current_entry"|"expanded_commits"|"commits_page"|"commits_total"
---@param callback                       fun(value: any): nil
---@return stl.c.IUnsubscribable
function State:subscribe(field, callback)
  local observable = self[field]
  assert(observable and observable.subscribe, "Invalid observable field: " .. field)
  return observable:subscribe(stl.c.Subscriber.new({ on_next = callback }))
end

---Set git subscription for auto-refresh
---@param subscription                   stl.c.IUnsubscribable
---@param debounce                       stl.timer.IDisposableCallable|nil
function State:set_git_subscription(subscription, debounce)
  self._git_subscription = subscription
  self._git_debounce = debounce
end

---Set TabClosed autocmd id
---@param autocmd_id                     integer
function State:set_tab_closed_autocmd(autocmd_id)
  self._tab_closed_autocmd = autocmd_id
end

----------------------------------------------------------------------------------------------------
-- Dispose
----------------------------------------------------------------------------------------------------

---Dispose all subscriptions and resources
function State:dispose()
  -- Dispose git subscription and debounce timer
  if self._git_subscription then
    self._git_subscription:unsubscribe()
    self._git_subscription = nil
  end
  if self._git_debounce then
    self._git_debounce:dispose()
    self._git_debounce = nil
  end

  -- Delete TabClosed autocmd
  if self._tab_closed_autocmd then
    pcall(vim.api.nvim_del_autocmd, self._tab_closed_autocmd)
    self._tab_closed_autocmd = nil
  end

  -- Dispose sign scheduler
  if self._scheduler_lnum_present then
    self._scheduler_lnum_present:dispose()
    self._scheduler_lnum_present = nil
  end

  -- Dispose observables
  self.commits:dispose()
  self.current_commit:dispose()
  self.current_entry:dispose()
  self.expanded_commits:dispose()
  self.commits_page:dispose()
  self.commits_total:dispose()
  self.lnum_present:dispose()
end

----------------------------------------------------------------------------------------------------
-- Active states registry
----------------------------------------------------------------------------------------------------

---@type table<integer, era.m.diffview.view.commits.State>
M.active_states = {}

---Get state for tab
---@param tabnr                          integer|nil
---@return era.m.diffview.view.commits.State|nil
function M.get(tabnr)
  tabnr = tabnr or vim.api.nvim_get_current_tabpage()
  return M.active_states[tabnr]
end

---Set state for tab
---@param tabnr                          integer
---@param state                          era.m.diffview.view.commits.State
function M.set(tabnr, state)
  M.active_states[tabnr] = state
end

---Remove state for tab
---@param tabnr                          integer
function M.remove(tabnr)
  local state = M.active_states[tabnr]
  if state then
    state:dispose()
    M.active_states[tabnr] = nil
  end
end

---Create new state for tab
---@param tabnr                          integer
---@param fold_unchanged                 boolean
---@return era.m.diffview.view.commits.State
function M.create(tabnr, fold_unchanged)
  local state = State.new(tabnr, fold_unchanged)
  M.set(tabnr, state)

  -- Setup TabClosed autocmd to clean up state when tab is closed directly
  local autocmd_id = vim.api.nvim_create_autocmd("TabClosed", {
    callback = function()
      -- `TabClosed` reports the closing tab's *number*, but `tabnr` here is a tabpage handle and
      -- the two diverge as soon as any tab has been closed. The handle is already invalid by the
      -- time the event fires, so test that directly instead of comparing identifiers.
      if not vim.api.nvim_tabpage_is_valid(tabnr) then
        M.remove(tabnr)
      end
    end,
  })
  state:set_tab_closed_autocmd(autocmd_id)

  return state
end

M.State = State

return M
