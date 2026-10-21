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
---@field public commits_page            stl.c.Observable                Observable<integer> (1-indexed)
---@field public commits_total           stl.c.Observable                Observable<integer>
---@field public lnum_present            stl.c.Observable                Observable<integer> line of currently displayed commit
---@field public path_filter             string|nil                      Path filter (file or directory path)
---@field protected _scheduler_lnum_present stl.c.Scheduler|nil
---@field protected _content_generation integer
---@field protected _disposed           boolean
---@field protected _commits_page_applied integer
---@field protected _materialization    era.m.diffview.view.commits.Cache
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

  -- Pagination state
  self.commits_page = stl.c.Observable.from_value(1)
  self.commits_total = stl.c.Observable.from_value(0)

  -- Sign state
  self.lnum_present = stl.c.Observable.from_value(-1)

  self._trees = {}
  self._materialization = require("era.m.diffview.view.commits.cache").new(self)
  self.path_filter = nil

  self._scheduler_lnum_present = nil
  self._content_generation = 0
  self._disposed = false
  self._commits_page_applied = 1

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
---@param commits                       era.m.diffview.ICommit[]
---@return nil
function State:set_commits(commits)
  self._materialization:reset(commits)
  self.commits:next(commits)
end

---Get current commit snapshot
---@return era.m.diffview.ICommit|nil
function State:get_current_commit()
  return self.current_commit:snapshot()
end

---Set current commit
---@param commit                        era.m.diffview.ICommit|nil
---@return nil
function State:set_current_commit(commit)
  self.current_commit:next(commit)
  self._materialization:touch(commit and commit.hash)
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

---@param kind                          "commits"|"files"
---@return era.view.ResultTree
function State:get_tree(kind)
  local tree = self._trees[kind]
  if not tree then
    tree = require("era.m.diffview.pane.tree").new()
    self._trees[kind] = tree
  end
  return tree
end

---@param hash                          string
---@return nil
function State:toggle_commit_expanded(hash)
  self:get_tree("commits"):set_expansion("commit:" .. hash, nil, false)
  self._materialization:touch(hash)
end

---@param hash                          string
---@return boolean
function State:is_commit_expanded(hash)
  local tree = self._trees.commits
  return tree ~= nil and tree:expanded("commit:" .. hash) == true
end

---@param hash                          string
---@return nil
function State:expand_commit(hash)
  self:get_tree("commits"):set_expansion("commit:" .. hash, true, false)
  self._materialization:touch(hash)
end

---@param hash                          string
---@return nil
function State:collapse_commit(hash)
  self:get_tree("commits"):set_expansion("commit:" .. hash, false, false)
  self._materialization:touch(hash)
end

---@return nil
function State:expand_all()
  for _, commit in ipairs(self:get_commits()) do
    self:expand_commit(commit.hash)
  end
end

---@return nil
function State:collapse_all()
  for _, commit in ipairs(self:get_commits()) do
    self:collapse_commit(commit.hash)
  end
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
  self._commits_page_applied = page
  self.commits_page:next(page)
end

---@param page                           integer
function State:request_commits_page(page)
  self.commits_page:next(page)
end

function State:reset_commits_page()
  self.commits_page:next(self._commits_page_applied)
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

---@param path                          string
---@return nil
function State:toggle_collapse(path)
  self:get_tree("files"):set_expansion(require("era.m.diffview.pane.tree").key(nil, path, true), nil, false)
end

---@param path                          string
---@return nil
function State:expand_dir(path)
  self:get_tree("files"):set_expansion(require("era.m.diffview.pane.tree").key(nil, path, true), true, false)
end

---@param path                          string
---@return nil
function State:collapse_dir(path)
  self:get_tree("files"):set_expansion(require("era.m.diffview.pane.tree").key(nil, path, true), false, false)
end

---@param path                          string
---@return boolean
function State:is_collapsed(path)
  local tree = self._trees.files
  return tree ~= nil
    and tree.state ~= nil
    and tree:expanded(require("era.m.diffview.pane.tree").key(nil, path, true)) == false
end

---@param hash                          string
---@param path                          string
---@return nil
function State:toggle_commit_dir(hash, path)
  self
    :get_tree("commits")
    :set_expansion(require("era.m.diffview.pane.tree").key("commit:" .. hash, path, true), nil, false)
end

---@param hash                          string
---@param path                          string
---@return nil
function State:expand_commit_dir(hash, path)
  self
    :get_tree("commits")
    :set_expansion(require("era.m.diffview.pane.tree").key("commit:" .. hash, path, true), true, false)
end

---@param hash                          string
---@param path                          string
---@return nil
function State:collapse_commit_dir(hash, path)
  self
    :get_tree("commits")
    :set_expansion(require("era.m.diffview.pane.tree").key("commit:" .. hash, path, true), false, false)
end

---@param hash                          string
---@param path                          string
---@return boolean
function State:is_commit_dir_collapsed(hash, path)
  local tree = self._trees.commits
  return tree ~= nil
    and tree.state ~= nil
    and tree:expanded(require("era.m.diffview.pane.tree").key("commit:" .. hash, path, true)) == false
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
-- Content request ownership
----------------------------------------------------------------------------------------------------

---@return integer|nil
function State:begin_content_request()
  if self._disposed then
    return nil
  end
  self._content_generation = self._content_generation + 1
  return self._content_generation
end

---@param generation                    integer
---@return boolean
function State:owns_content_request(generation)
  return not self._disposed and self._content_generation == generation
end

---@return integer
function State:content_generation()
  return self._content_generation
end

---@return era.m.diffview.view.commits.Cache
function State:materialization()
  return self._materialization
end

---@return boolean
function State:is_disposed()
  return self._disposed
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
---@param field                         "commits"|"current_commit"|"current_entry"|"commits_page"|"commits_total"
---@param callback                       fun(value: any): nil
---@return stl.c.IUnsubscribable
function State:subscribe(field, callback)
  local observable = self[field]
  assert(observable and observable.subscribe, "Invalid observable field: " .. field)
  return observable:subscribe(stl.c.Subscriber.new({ on_next = callback }))
end

----------------------------------------------------------------------------------------------------
-- Dispose
----------------------------------------------------------------------------------------------------

---Dispose all subscriptions and resources
function State:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  self._content_generation = self._content_generation + 1

  -- Dispose sign scheduler
  if self._scheduler_lnum_present then
    self._scheduler_lnum_present:dispose()
    self._scheduler_lnum_present = nil
  end

  -- Dispose observables
  self.commits:dispose()
  self.current_commit:dispose()
  self.current_entry:dispose()
  self._materialization:dispose()
  for _, tree in pairs(self._trees) do
    tree:dispose()
  end
  self._trees = {}
  self.commits_page:dispose()
  self.commits_total:dispose()
  self.lnum_present:dispose()
end

M.State = State

return M
