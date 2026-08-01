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
---@field public entries                 stl.c.Observable                Observable<era.m.diffview.IFileEntry[]>
---@field public current_entry           stl.c.Observable                Observable<era.m.diffview.IFileEntry|nil>
---@field public collapsed_dirs          table<string, boolean>          Collapsed directory paths
---@field protected _git_subscription    stl.c.IUnsubscribable|nil
---@field protected _git_debounce        stl.timer.IDisposableCallable|nil
---@field protected _tab_closed_autocmd  integer|nil
local State = {}
State.__index = State

---Create a new workspace state instance
---@param tabnr                          integer
---@return era.m.diffview.view.workspace.State
function State.new(tabnr)
  local self = setmetatable({}, State)

  self.tabnr = tabnr
  self.layout_type = 1 -- Default: changes + sbs

  self.entries = stl.c.Observable.from_value({})
  self.current_entry = stl.c.Observable.from_value(nil)
  self.collapsed_dirs = {}

  self._git_subscription = nil
  self._git_debounce = nil
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

---Set entries
---@param entries                        era.m.diffview.IFileEntry[]
function State:set_entries(entries)
  self.entries:next(entries)
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

----------------------------------------------------------------------------------------------------
-- Directory collapse management
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

---Expand all directories
function State:expand_all()
  self.collapsed_dirs = {}
end

---Collapse all directories (from current entries)
function State:collapse_all()
  local entries = self:get_entries()
  local dirs = {} ---@type table<string, boolean>

  for _, entry in ipairs(entries) do
    local dir = vim.fn.fnamemodify(entry.filepath, ":h")
    while dir ~= "." and dir ~= "" do
      dirs[dir] = true
      dir = vim.fn.fnamemodify(dir, ":h")
    end
  end

  self.collapsed_dirs = dirs
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
---@return era.m.diffview.view.workspace.State
function M.create(tabnr)
  local state = State.new(tabnr)
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
