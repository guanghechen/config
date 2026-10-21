---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.session" ---@type string

local CommitsState = require("era.m.diffview.view.commits.state").State
local Refresh = require("era.m.diffview.view.workspace.refresh")
local WorkspaceState = require("era.m.diffview.view.workspace.state").State
local commits_action = require("era.m.diffview.view.commits.action")
local commits_keymap = require("era.m.diffview.view.commits.keymap")
local commits_tabline = require("era.m.diffview.view.commits.tabline")
local commits_view = require("era.m.diffview.view.commits.view")
local data = require("era.m.diffview.data")
local pane_changes = require("era.m.diffview.pane.changes")
local pane_commits = require("era.m.diffview.pane.commits")
local sbs_keymap = require("era.m.diffview.view.sbs_keymap")
local workspace_action = require("era.m.diffview.view.workspace.action")
local workspace_keymap = require("era.m.diffview.view.workspace.keymap")
local workspace_tabline = require("era.m.diffview.view.workspace.tabline")
local workspace_view = require("era.m.diffview.view.workspace.view")
local workspace_winline = require("era.m.diffview.view.workspace.winline")

---Diffview tabs. Each tab has one session, which owns its layout, state, keymaps and what closing releases.
---@class era.m.diffview.session
local M = {}

---@type table<integer, era.m.diffview.Session>
local sessions = {}

---@type integer|nil
local group = nil

---@param keymaps                       stl.t.IKeymap[]
---@param mode                          string
---@param key                           string
---@return stl.t.IKeymap|nil
local function find_keymap(keymaps, mode, key)
  for _, keymap in ipairs(keymaps) do
    if keymap.key == key and vim.list_contains(keymap.modes, mode) then
      return keymap
    end
  end
end

---Side-by-side buffers are shared across tabs, so their mappings find the current tab's keymap when pressed.
---@param mode                          string
---@param key                           string
---@return stl.t.IKeymap|nil
local function resolve_sbs(mode, key)
  local session = M.current()
  return session and find_keymap(session:sbs_keymaps(), mode, key)
end

---@param layout                        { sbs_left_winnr: integer|nil, sbs_right_winnr: integer|nil }
---@param setup                         fun(bufnr: integer): nil
---@return nil
local function setup_sbs_windows(layout, setup)
  for _, winnr in ipairs({ layout.sbs_left_winnr, layout.sbs_right_winnr }) do
    if vim.api.nvim_win_is_valid(winnr) then
      setup(vim.api.nvim_win_get_buf(winnr))
    end
  end
end

---Keeps the commit sign of a commits pane on its present commit.
---@param ctx                           era.m.diffview.view.commits.IContext
---@return nil
local function setup_commit_signs(ctx)
  local bufnr = ctx.layout.commits_bufnr ---@type integer|nil
  if not bufnr then
    return
  end
  local state = ctx.state
  pane_commits.clear_signs(bufnr)
  state:set_sign_scheduler(stl.c.Scheduler.new({
    name = string.format("diffview:commits#%d#lnum_present", ctx.layout.tabnr),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = stl.fn.truthy,
    value = stl.c.Observable.from_value(true),
    task = function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        pane_commits.update_sign_present(bufnr, state:get_lnum_present())
      end
    end,
  }))
  stl.fn.observe({ state.lnum_present }, function()
    state:schedule_sign_present()
  end)
end

---Closes the session of every tab that no longer exists.
---@return nil
local function watch_tabs()
  if group then
    return
  end
  group = vim.api.nvim_create_augroup(__module_name__, { clear = true })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      for tabnr, session in pairs(sessions) do
        if not vim.api.nvim_tabpage_is_valid(tabnr) then
          session:close()
        end
      end
    end,
  })
end

----------------------------------------------------------------------------------------------------
-- Session
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.Session
---@field public kind                   "workspace"|"commits"
---@field public tabnr                  integer
---@field public close                  fun(self: era.m.diffview.Session): nil
---@field public navigate_window        fun(self: era.m.diffview.Session, direction: "h"|"j"|"k"|"l"): boolean
---@field public refresh                fun(self: era.m.diffview.Session): nil
---@field public reveal                 fun(self: era.m.diffview.Session): nil
---@field public sbs_keymaps            fun(self: era.m.diffview.Session): stl.t.IKeymap[]
---@field public toggle_commits         fun(self: era.m.diffview.Session): nil
---@field public toggle_files           fun(self: era.m.diffview.Session): nil
---@field protected _cleanups           (fun(): nil)[]
---@field protected _closed             boolean
local Session = {}
Session.__index = Session

---@param cleanup                       fun(): nil
---@return nil
function Session:on_close(cleanup)
  self._cleanups[#self._cleanups + 1] = cleanup
end

---@return boolean
function Session:is_closed()
  return self._closed
end

---Releases what the session registered; reports whether this call closed it.
---@return boolean
function Session:__release__()
  if self._closed then
    return false
  end
  self._closed = true
  sessions[self.tabnr] = nil
  for _, cleanup in ipairs(self._cleanups) do
    cleanup()
  end
  self._cleanups = {}
  return true
end

----------------------------------------------------------------------------------------------------
-- History
----------------------------------------------------------------------------------------------------

---The workspace's History pane: a commits view inside the workspace layout, sharing its preview.
---@class era.m.diffview.History : era.m.diffview.view.commits.IContext
---@field public layout                 era.m.diffview.view.commits.ILayout
---@field public state                  era.m.diffview.view.commits.State
---@field public workspace              era.m.diffview.WorkspaceSession
local History = {}
History.__index = History

---@return fun(): boolean
function History:begin_preview()
  local layout, state, workspace_state = self.workspace.layout, self.state, self.workspace.state
  local generation = workspace_view.begin_preview(layout, "history") ---@type integer
  return function()
    return workspace_view.owns_preview(layout, generation)
      and not workspace_state:is_disposed()
      and not state:is_disposed()
  end
end

---@return nil
function History:render_winline()
  workspace_winline.render_history(self)
end

---@return stl.t.IKeymap[]
function History:get_keymaps()
  return self.workspace:get_keymaps()
end

---@return nil
function History:setup_commits()
  self.workspace:setup_history()
end

---History has no file tree pane.
---@return nil
function History:setup_filetree() end

---@param bufnr                         integer
---@return nil
function History:setup_sbs(bufnr)
  self.workspace:setup_sbs(bufnr)
end

---@return nil
function History:setup_keymaps()
  self.workspace:setup_keymaps()
end

---@return nil
function History:close()
  self.workspace:close()
end

----------------------------------------------------------------------------------------------------
-- Workspace session
----------------------------------------------------------------------------------------------------

---The repository Git workspace: Changes, History and the side-by-side preview.
---@class era.m.diffview.WorkspaceSession : era.m.diffview.Session, era.m.diffview.view.workspace.IContext
---@field public layout                 era.m.diffview.view.workspace.ILayout
---@field public state                  era.m.diffview.view.workspace.State
---@field public history                era.m.diffview.History
---@field public pending_discards       table<string, stl.c.Future> Untracked discards in flight, by path.
local WorkspaceSession = setmetatable({}, { __index = Session })
WorkspaceSession.__index = WorkspaceSession

---@return stl.t.IKeymap[]
function WorkspaceSession:get_keymaps()
  return workspace_keymap.get_help_keymaps(self)
end

---@return stl.t.IKeymap[]
function WorkspaceSession:sbs_keymaps()
  return workspace_keymap.gen_sbs(self)
end

---@return nil
function WorkspaceSession:setup_changes()
  workspace_keymap.setup_changes(self)
end

---@return nil
function WorkspaceSession:setup_history()
  workspace_keymap.setup_history(self)
end

---@param bufnr                         integer
---@return nil
function WorkspaceSession:setup_sbs(bufnr)
  sbs_keymap.setup(self:sbs_keymaps(), bufnr, resolve_sbs)
end

---@return nil
function WorkspaceSession:setup_keymaps()
  self:setup_changes()
  self:setup_history()
  setup_sbs_windows(self.layout, function(bufnr)
    self:setup_sbs(bufnr)
  end)
end

---@return nil
function WorkspaceSession:refresh()
  self.state:request_refresh()
  stl.async.run(function()
    commits_action.refresh(self.history)
  end)
end

---@return nil
function WorkspaceSession:reveal()
  workspace_action.reveal(self)
end

---@return nil
function WorkspaceSession:toggle_commits()
  workspace_action.toggle_history(self)
end

---@return nil
function WorkspaceSession:toggle_files()
  workspace_action.toggle_sidebar(self)
end

---Moving left from the left preview window returns to Changes.
---@param direction                     "h"|"j"|"k"|"l"
---@return boolean handled
function WorkspaceSession:navigate_window(direction)
  if direction ~= "h" or vim.api.nvim_get_current_win() ~= self.layout.sbs_left_winnr then
    return false
  end
  return workspace_view.focus_changes(self.layout)
end

---@return nil
function WorkspaceSession:close()
  if self:__release__() then
    self.history.state:dispose()
    self.state:dispose()
    workspace_view.destroy(self.layout)
  end
end

---Refreshes Changes on Git status events. Index-only snapshots carry enough blob identity to absorb the
---event of the view that staged; broader refreshes may include worktree changes without such an identity.
---@return nil
function WorkspaceSession:__subscribe_git__()
  local state = self.state
  state:set_refresh(Refresh.new({
    is_stale = function()
      return not data.matches_status_entries(state:get_entries(), era.m.git.state.snapshot():entries())
    end,
    is_valid = function()
      return not self._closed and vim.api.nvim_tabpage_is_valid(self.tabnr)
    end,
    run = function(token)
      if not self._closed then
        workspace_action.refresh(self, token)
      end
    end,
  }))
  local subscription = era.m.git.state.o_refreshed:subscribe(
    stl.c.Subscriber.new({
      on_next = function(event)
        if event.change_scope == "index" then
          state:request_refresh_if_stale()
        else
          state:request_refresh()
        end
      end,
    }),
    true
  )
  self:on_close(function()
    subscription:unsubscribe()
  end)
end

---Renders Changes again when their width changes, and resyncs their heights when the terminal height does.
---@return nil
function WorkspaceSession:__watch_changes_size__()
  local last = workspace_view.measure_changes(self.layout)
  local autocmd_id = vim.api.nvim_create_autocmd("WinResized", {
    callback = function()
      if self._closed then
        return
      end
      local current = workspace_view.measure_changes(self.layout)
      local resize = workspace_view.changes_resize(last, current)
      last = current
      if resize.sync_heights then
        workspace_view.sync_changes_heights(self.layout)
      end
      if resize.remember_width then
        dot.context.diffview.panel_width:next(resize.remember_width)
      end
      if resize.render then
        workspace_view.render_changes(self)
      end
    end,
  })
  self:on_close(function()
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
  end)
end

---Selects the first visible entry in panel order, Staged then Unstaged, and previews it.
---@return nil
function WorkspaceSession:__select_first_entry__()
  local entries = workspace_view.get_visible_entries(self.state:get_entries())
  if #entries == 0 then
    return
  end
  local first = entries[1] ---@type era.m.diffview.IFileEntry
  for _, pane in ipairs(workspace_view.get_changes_panes(self.layout)) do
    if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
      local row, visible = pane_changes.find_adjacent_entry(pane.bufnr, nil, 1)
      if row and visible then
        first = self.state:find_entry(visible.filepath, visible.stage_type) or visible
        if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
          vim.api.nvim_win_set_cursor(pane.winnr, { row, 0 })
          vim.api.nvim_set_current_win(pane.winnr)
        end
        break
      end
    end
  end
  self.state:set_current_entry(first)
  workspace_view.open_entry(self, first)
end

----------------------------------------------------------------------------------------------------
-- Commits session
----------------------------------------------------------------------------------------------------

---The standalone Git log, optionally limited to one path.
---@class era.m.diffview.CommitsSession : era.m.diffview.Session, era.m.diffview.view.commits.IContext
---@field public layout                 era.m.diffview.view.commits.ILayout
---@field public state                  era.m.diffview.view.commits.State
---@field protected _preview_generation integer
local CommitsSession = setmetatable({}, { __index = Session })
CommitsSession.__index = CommitsSession

---A preview stays current until the next one begins or the session closes.
---@return fun(): boolean
function CommitsSession:begin_preview()
  self._preview_generation = self._preview_generation + 1
  local generation = self._preview_generation ---@type integer
  return function()
    return self._preview_generation == generation and not self._closed
  end
end

---The standalone log has no pane winline.
---@return nil
function CommitsSession:render_winline() end

---@return stl.t.IKeymap[]
function CommitsSession:get_keymaps()
  return commits_keymap.get_help_keymaps(self)
end

---@return stl.t.IKeymap[]
function CommitsSession:sbs_keymaps()
  return commits_keymap.gen_sbs(self)
end

---@return nil
function CommitsSession:setup_commits()
  commits_keymap.setup_commits(self)
end

---@return nil
function CommitsSession:setup_filetree()
  commits_keymap.setup_filetree(self)
end

---@param bufnr                         integer
---@return nil
function CommitsSession:setup_sbs(bufnr)
  sbs_keymap.setup(self:sbs_keymaps(), bufnr, resolve_sbs)
end

---@return nil
function CommitsSession:setup_keymaps()
  self:setup_commits()
  self:setup_filetree()
  setup_sbs_windows(self.layout, function(bufnr)
    self:setup_sbs(bufnr)
  end)
end

---@return nil
function CommitsSession:refresh()
  stl.async.run(function()
    commits_action.refresh(self)
  end)
end

---@return nil
function CommitsSession:reveal()
  commits_action.reveal(self)
end

---@return nil
function CommitsSession:toggle_commits()
  commits_action.toggle_commits(self)
end

---@return nil
function CommitsSession:toggle_files()
  commits_action.toggle_filetree(self)
end

---@return boolean handled
function CommitsSession:navigate_window()
  return false
end

---@return nil
function CommitsSession:close()
  if self:__release__() then
    self.state:dispose()
    commits_view.destroy(self.layout)
  end
end

----------------------------------------------------------------------------------------------------
-- Lookup
----------------------------------------------------------------------------------------------------

-- A tab can close without TabClosed reaching the sessions; its session then closes when it is looked up.
---@generic T
---@param session                       T|nil
---@return T|nil
local function live(session)
  ---@cast session era.m.diffview.Session|nil
  if session and not vim.api.nvim_tabpage_is_valid(session.tabnr) then
    session:close()
    return nil
  end
  return session
end

---@return era.m.diffview.Session|nil
function M.current()
  return live(sessions[vim.api.nvim_get_current_tabpage()])
end

---@param tabnr                         ?integer Defaults to the current tab.
---@return era.m.diffview.WorkspaceSession|nil
function M.workspace(tabnr)
  local session = live(sessions[tabnr or vim.api.nvim_get_current_tabpage()])
  ---@cast session era.m.diffview.WorkspaceSession|nil
  return session and session.kind == "workspace" and session or nil
end

---@param tabnr                         ?integer Defaults to the current tab.
---@return era.m.diffview.CommitsSession|nil
function M.commits(tabnr)
  local session = live(sessions[tabnr or vim.api.nvim_get_current_tabpage()])
  ---@cast session era.m.diffview.CommitsSession|nil
  return session and session.kind == "commits" and session or nil
end

----------------------------------------------------------------------------------------------------
-- Opening
----------------------------------------------------------------------------------------------------

---Opens the repository Git workspace, or returns to its tab when it is open.
---@param opts                          ?{ layout: integer|nil }
---@return era.m.diffview.WorkspaceSession|nil
function M.open_workspace(opts)
  workspace_tabline.register()
  if not dot.path.workspace() then
    stl.reporter.warn({ from = __module_name__, subject = "open_workspace", message = "Not in a git repository" })
    return nil
  end
  for _, session in pairs(sessions) do
    if session.kind == "workspace" and live(session) then
      vim.api.nvim_set_current_tabpage(session.tabnr)
      ---@cast session era.m.diffview.WorkspaceSession
      return session
    end
  end

  watch_tabs()
  local fold_unchanged = dot.context.diffview.flag_fold_unchanges:snapshot() ---@type boolean
  local layout = workspace_view.create_layout(opts and opts.layout or 1)
  ---@type era.m.diffview.WorkspaceSession
  local session = setmetatable({
    kind = "workspace",
    tabnr = layout.tabnr,
    layout = layout,
    state = WorkspaceState.new(layout.tabnr, fold_unchanged),
    pending_discards = {},
    _cleanups = {},
    _closed = false,
  }, WorkspaceSession)
  session.history = setmetatable({
    layout = layout.history,
    state = CommitsState.new(layout.tabnr, fold_unchanged),
    workspace = session,
  }, History)
  sessions[session.tabnr] = session

  session:setup_keymaps()
  session:__subscribe_git__()
  session:__watch_changes_size__()
  setup_commit_signs(session.history)
  workspace_winline.setup(session)

  session.state:request_refresh(function()
    session:__select_first_entry__()
  end)
  local history = session.history
  stl.async.run(function()
    if not commits_action.refresh(history) then
      return
    end
    local first = history.state:get_commits()[1] ---@type era.m.diffview.ICommit|nil
    if first then
      history.state:set_current_commit(first)
      history.state:set_lnum_present(pane_commits.find_commit_line(layout.history.commits_bufnr, first.hash) or 1)
      history.state:schedule_sign_present()
    end
  end)
  return session
end

---Opens the Git log, limited to `opts.path` when given, or returns to the log of that path when it is open.
---@param opts                          ?{ layout: integer|nil, path: string|nil }
---@return era.m.diffview.CommitsSession|nil
function M.open_log(opts)
  commits_tabline.register()
  if not dot.path.workspace() then
    stl.reporter.warn({ from = __module_name__, subject = "open_log", message = "Not in a git repository" })
    return nil
  end
  local path = opts and opts.path ---@type string|nil
  for _, session in pairs(sessions) do
    ---@cast session era.m.diffview.CommitsSession
    if session.kind == "commits" and live(session) and session.state:get_path_filter() == path then
      vim.api.nvim_set_current_tabpage(session.tabnr)
      return session
    end
  end

  watch_tabs()
  local layout = commits_view.create_layout(opts and opts.layout or dot.context.diffview.commits_layout:snapshot())
  ---@type era.m.diffview.CommitsSession
  local session = setmetatable({
    kind = "commits",
    tabnr = layout.tabnr,
    layout = layout,
    state = CommitsState.new(layout.tabnr, dot.context.diffview.flag_fold_unchanges:snapshot()),
    _preview_generation = 0,
    _cleanups = {},
    _closed = false,
  }, CommitsSession)
  if path then
    session.state:set_path_filter(path)
  end
  sessions[session.tabnr] = session

  setup_commit_signs(session)
  session:setup_keymaps()

  stl.async.run(function()
    if not commits_action.refresh(session) then
      return
    end
    local first = session.state:get_commits()[1] ---@type era.m.diffview.ICommit|nil
    if first then
      session.state:set_current_commit(first)
      session.state:set_lnum_present(1)
      session.state:schedule_sign_present()
    end
    dot.state.status.dirtier_tabline:mark_dirty()
  end)
  return session
end

return M
