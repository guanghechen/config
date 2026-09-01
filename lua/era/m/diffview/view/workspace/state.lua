---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.state" ---@type string

---Workspace view state management.
---@class era.m.diffview.view.workspace.state
local M = {}

----------------------------------------------------------------------------------------------------
-- State class
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.workspace.State
---@field public tabnr                   integer
---@field public layout_type             integer                         Current layout (1-3)
---@field public fold_unchanged          boolean                         Current diff fold policy
---@field public entries                 stl.c.Observable                Observable<era.m.diffview.IFileEntry[]>
---@field public current_entry           stl.c.Observable                Observable<era.m.diffview.IFileEntry|nil>
---@field public collapsed_dirs          table<stl.m.diffview.StageTypeEnum, table<string, boolean>> Per-pane tree state
---@field protected _disposed            boolean
---@field protected _git_subscription    stl.c.IUnsubscribable|nil
---@field protected _entries_snapshot_applied boolean
---@field protected _refresh             era.m.diffview.view.workspace.Refresh|nil
---@field protected _resize_autocmd_id   integer|nil
---@field protected _tab_closed_autocmd  integer|nil
local State = {}
State.__index = State

---Create a new workspace state instance
---@param tabnr                          integer
---@param fold_unchanged                 boolean
---@return era.m.diffview.view.workspace.State
function State.new(tabnr, fold_unchanged)
  local self = setmetatable({}, State)

  self.tabnr = tabnr
  self.layout_type = 1 -- Default: changes + sbs
  self.fold_unchanged = fold_unchanged

  self.entries = stl.c.Observable.from_value({})
  self.current_entry = stl.c.Observable.from_value(nil)
  self.collapsed_dirs = { staged = {}, unstaged = {} }

  self._disposed = false
  self._git_subscription = nil
  self._entries_snapshot_applied = false
  self._refresh = nil
  self._resize_autocmd_id = nil
  self._tab_closed_autocmd = nil

  return self
end

----------------------------------------------------------------------------------------------------
-- Entry management
----------------------------------------------------------------------------------------------------

---Get current entries snapshot
---@return era.m.diffview.IFileEntry[]
function State:get_entries()
  return self.entries:snapshot()
end

---Whether the current entries snapshot and all dependent view state were applied successfully.
---@return boolean
function State:is_entries_snapshot_applied()
  return self._entries_snapshot_applied
end

---Replace entries and keep the snapshot pending until dependent view state is applied.
---@param entries                        era.m.diffview.IFileEntry[]
function State:set_entries(entries)
  self._entries_snapshot_applied = false
  self.entries:next(entries)
end

---Mark the current entries snapshot and its dependent view state as applied.
function State:commit_entries_snapshot()
  self._entries_snapshot_applied = true
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

---Find entry by filepath and stage_type
---@param filepath                       string
---@param stage_type                     "staged"|"unstaged"|nil
---@return era.m.diffview.IFileEntry|nil
function State:find_entry(filepath, stage_type)
  local entries = self:get_entries()
  for _, entry in ipairs(entries) do
    if entry.filepath == filepath and entry.stage_type == stage_type then
      return entry
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------
-- Layout management
----------------------------------------------------------------------------------------------------

---Get layout type
---@return integer
function State:get_layout_type()
  return self.layout_type
end

---Set layout type
---@param layout_type                    integer
function State:set_layout_type(layout_type)
  self.layout_type = layout_type
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
-- Directory collapse management
----------------------------------------------------------------------------------------------------

---Check if a directory is collapsed in one Changes pane.
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@param dir_path                       string
---@return boolean
function State:is_collapsed(stage_type, dir_path)
  return self.collapsed_dirs[stage_type][dir_path] == true
end

---Toggle directory collapse state in one Changes pane.
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@param dir_path                       string
function State:toggle_collapse(stage_type, dir_path)
  local collapsed_dirs = self.collapsed_dirs[stage_type]
  collapsed_dirs[dir_path] = not collapsed_dirs[dir_path]
end

---Expand a directory in one Changes pane.
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@param dir_path                       string
function State:expand_dir(stage_type, dir_path)
  self.collapsed_dirs[stage_type][dir_path] = nil
end

---Collapse a directory in one Changes pane.
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@param dir_path                       string
function State:collapse_dir(stage_type, dir_path)
  self.collapsed_dirs[stage_type][dir_path] = true
end

---Expand all directories in one Changes pane.
---@param stage_type                     stl.m.diffview.StageTypeEnum
function State:expand_all(stage_type)
  self.collapsed_dirs[stage_type] = {}
end

---Collapse all directories in one Changes pane.
---@param stage_type                     stl.m.diffview.StageTypeEnum
function State:collapse_all(stage_type)
  local entries = self:get_entries()
  local dirs = {} ---@type table<string, boolean>

  for _, entry in ipairs(entries) do
    if entry.stage_type == stage_type then
      local dir = vim.fn.fnamemodify(entry.filepath, ":h")
      while dir ~= "." and dir ~= "" do
        dirs[dir] = true
        dir = vim.fn.fnamemodify(dir, ":h")
      end
    end
  end

  self.collapsed_dirs[stage_type] = dirs
end

---Get one pane's collapsed dirs snapshot.
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@return table<string, boolean>
function State:get_collapsed_dirs(stage_type)
  return vim.tbl_extend("force", {}, self.collapsed_dirs[stage_type])
end

---Set one pane's collapsed dirs.
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@param collapsed_dirs                 table<string, boolean>
function State:set_collapsed_dirs(stage_type, collapsed_dirs)
  self.collapsed_dirs[stage_type] = collapsed_dirs
end

----------------------------------------------------------------------------------------------------
-- Subscriptions
----------------------------------------------------------------------------------------------------

---Subscribe to observable field changes
---@param field                          "entries"|"current_entry"
---@param callback                       fun(value: any): nil
---@return stl.c.IUnsubscribable
function State:subscribe(field, callback)
  local observable = self[field]
  assert(observable and observable.subscribe, "Invalid observable field: " .. field)
  return observable:subscribe(stl.c.Subscriber.new({ on_next = callback }))
end

---Set the workspace refresh owner.
---@param refresh                        era.m.diffview.view.workspace.Refresh
function State:set_refresh(refresh)
  assert(not self._disposed, "Workspace state is disposed")
  if self._refresh then
    self._refresh:dispose()
  end
  self._refresh = refresh
end

---Request a workspace refresh.
---@param callback                       ?fun(): nil
function State:request_refresh(callback)
  if self._disposed then
    return
  end
  assert(self._refresh, "Workspace refresh owner is not initialized"):request(callback)
end

---Request a workspace refresh when Git state no longer matches the view.
function State:request_refresh_if_stale()
  if self._disposed then
    return
  end
  assert(self._refresh, "Workspace refresh owner is not initialized"):request_if_stale()
end

---@return boolean
function State:is_disposed()
  return self._disposed
end

---Set git subscription for auto-refresh.
---@param subscription                   stl.c.IUnsubscribable
function State:set_git_subscription(subscription)
  self._git_subscription = subscription
end

---Set Changes pane resize autocmd id.
---@param autocmd_id                     integer
function State:set_resize_autocmd(autocmd_id)
  self._resize_autocmd_id = autocmd_id
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
  if self._disposed then
    return
  end
  self._disposed = true

  -- Stop new refresh requests before disposing their owner.
  if self._git_subscription then
    self._git_subscription:unsubscribe()
    self._git_subscription = nil
  end
  if self._refresh then
    self._refresh:dispose()
    self._refresh = nil
  end

  -- Delete TabClosed autocmd
  if self._tab_closed_autocmd then
    pcall(vim.api.nvim_del_autocmd, self._tab_closed_autocmd)
    self._tab_closed_autocmd = nil
  end
  if self._resize_autocmd_id then
    pcall(vim.api.nvim_del_autocmd, self._resize_autocmd_id)
    self._resize_autocmd_id = nil
  end

  -- Dispose observables
  self.entries:dispose()
  self.current_entry:dispose()
end

----------------------------------------------------------------------------------------------------
-- Active states registry
----------------------------------------------------------------------------------------------------

---@type table<integer, era.m.diffview.view.workspace.State>
M.active_states = {}

---Get state for tab
---@param tabnr                          integer|nil
---@return era.m.diffview.view.workspace.State|nil
function M.get(tabnr)
  tabnr = tabnr or vim.api.nvim_get_current_tabpage()
  return M.active_states[tabnr]
end

---Set state for tab
---@param tabnr                          integer
---@param state                          era.m.diffview.view.workspace.State
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
---@return era.m.diffview.view.workspace.State
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
