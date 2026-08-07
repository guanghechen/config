---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.cmd" ---@type string

---@class era.m.diffview.cmd
local M = {}

----------------------------------------------------------------------------------------------------
-- Command implementations: workspace (Git Diff)
----------------------------------------------------------------------------------------------------

---Open Git Diff view (staged/unstaged changes)
---@param opts                        { layout: integer|nil }|nil
function M.open(opts)
  local workspace_action = require("era.m.diffview.view.workspace.action")
  local workspace_keymap = require("era.m.diffview.view.workspace.keymap")
  local workspace_state = require("era.m.diffview.view.workspace.state")
  local workspace_tabline = require("era.m.diffview.view.workspace.tabline")
  local workspace_view = require("era.m.diffview.view.workspace.view")

  -- Register tabline nvimbar for workspace (idempotent)
  workspace_tabline.register()

  local workspace = dot.path.workspace()
  local layout_type = opts and opts.layout or 1

  if not workspace then
    stl.reporter.warn({
      from = __module_name__,
      subject = "open",
      message = "Not in a git repository",
    })
    return
  end

  -- Check if workspace diffview already open in any tab
  for tabnr, _ in pairs(workspace_state.active_states) do
    if vim.api.nvim_tabpage_is_valid(tabnr) then
      -- Switch to existing tab
      vim.api.nvim_set_current_tabpage(tabnr)
      return
    end
  end

  -- Create layout
  local lyt = workspace_view.create_layout(layout_type)
  workspace_view.set_layout(lyt.tabnr, lyt)

  -- Create state
  local st = workspace_state.create(lyt.tabnr)

  ---@type era.m.diffview.view.workspace.IContext
  local ctx = {
    layout = lyt,
    state = st,
  }

  -- Setup keymaps
  workspace_keymap.setup_changes(ctx)
  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    workspace_keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(lyt.sbs_left_winnr))
  end
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    workspace_keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(lyt.sbs_right_winnr))
  end

  -- Setup git subscription for auto-refresh
  M.__setup_git_subscription_workspace__(st, ctx)

  -- Fetch and render data
  stl.async.run(function()
    workspace_action.refresh(ctx)

    -- Auto-select first entry if any
    local entries = st:get_entries()
    if #entries > 0 then
      local first_entry = entries[1] ---@type era.m.diffview.IFileEntry

      -- Move cursor to first file line (skip directories)
      if lyt.changes_bufnr and vim.api.nvim_buf_is_valid(lyt.changes_bufnr) then
        local pane_changes = require("era.m.diffview.pane.changes")
        local line_map = pane_changes.get_line_map(lyt.changes_bufnr)
        if line_map then
          for i, item in ipairs(line_map) do
            if item.type == "file" and item.entry ~= nil then
              local visible_entry = assert(item.entry) ---@type era.m.diffview.IFileEntry
              first_entry = st:find_entry(visible_entry.filepath, visible_entry.stage_type) or visible_entry
              if lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
                vim.api.nvim_win_set_cursor(lyt.changes_winnr, { i, 0 })
              end
              break
            end
          end
        end
      end

      st:set_current_entry(first_entry)
      workspace_view.open_entry(ctx, first_entry)
    end
  end)
end

----------------------------------------------------------------------------------------------------
-- Command implementations: log (commits)
----------------------------------------------------------------------------------------------------

---Open Git Log view
---@param opts                        { layout: integer|nil, path: string|nil }|nil
function M.log(opts)
  local commits_action = require("era.m.diffview.view.commits.action")
  local commits_keymap = require("era.m.diffview.view.commits.keymap")
  local commits_state = require("era.m.diffview.view.commits.state")
  local commits_tabline = require("era.m.diffview.view.commits.tabline")
  local commits_view = require("era.m.diffview.view.commits.view")
  local pane_commits = require("era.m.diffview.pane.commits")

  -- Register tabline nvimbar for commits (idempotent)
  commits_tabline.register()

  local workspace = dot.path.workspace()
  local layout_type = opts and opts.layout or dot.context.diffview.commits_layout:snapshot()
  local path_filter = opts and opts.path ---@type string|nil

  if not workspace then
    stl.reporter.warn({
      from = __module_name__,
      subject = "log",
      message = "Not in a git repository",
    })
    return
  end

  -- Check if commits diffview already open with same path_filter
  for tabnr, st in pairs(commits_state.active_states) do
    if vim.api.nvim_tabpage_is_valid(tabnr) then
      if st:get_path_filter() == path_filter then
        -- Switch to existing tab with same filter
        vim.api.nvim_set_current_tabpage(tabnr)
        return
      end
    end
  end

  -- Create layout
  local lyt = commits_view.create_layout(layout_type)
  commits_view.set_layout(lyt.tabnr, lyt)

  -- Create state
  local st = commits_state.create(lyt.tabnr)

  -- Set path filter if provided
  if path_filter then
    st:set_path_filter(path_filter)
  end

  ---@type era.m.diffview.view.commits.IContext
  local ctx = {
    layout = lyt,
    state = st,
  }

  -- Setup sign scheduler for statuscolumn (present sign only)
  if lyt.commits_bufnr then
    local fullname = string.format("diffview:commits#%d", lyt.tabnr)
    local commits_bufnr = lyt.commits_bufnr ---@type integer

    -- Clear any existing signs first
    pane_commits.clear_signs(commits_bufnr)

    ---@type stl.c.Scheduler
    local scheduler_lnum_present = stl.c.Scheduler.new({
      name = string.format("%s#lnum_present", fullname),
      mode = "debounce",
      delay = 64,
      timeout = 0,
      silent = stl.fn.truthy,
      value = stl.c.Observable.from_value(true),
      task = function()
        if vim.api.nvim_buf_is_valid(commits_bufnr) then
          local lnum_present = st:get_lnum_present()
          pane_commits.update_sign_present(commits_bufnr, lnum_present)
        end
      end,
    })

    st:set_sign_scheduler(scheduler_lnum_present)

    -- Observe lnum_present changes to update sign
    stl.fn.observe({ st.lnum_present }, function()
      st:schedule_sign_present()
    end)
  end

  -- Setup keymaps
  commits_keymap.setup_commits(ctx)
  if lyt.filetree_bufnr then
    commits_keymap.setup_filetree(ctx)
  end
  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    commits_keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(lyt.sbs_left_winnr))
  end
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    commits_keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(lyt.sbs_right_winnr))
  end

  -- Fetch and render data
  stl.async.run(function()
    commits_action.refresh(ctx)

    -- Set first commit as default current_commit
    local commits = st:get_commits()
    if #commits > 0 then
      local first_commit = commits[1]
      st:set_current_commit(first_commit)
      st:set_lnum_present(1)

      -- Explicitly trigger initial sign update
      st:schedule_sign_present()
    end

    -- Update tabline
    dot.state.status.dirtier_tabline:mark_dirty()
  end)
end

----------------------------------------------------------------------------------------------------
-- Close and refresh
----------------------------------------------------------------------------------------------------

---Close current diffview
function M.close()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local tabtype = vim.t[tabnr].tabtype

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local workspace_action = require("era.m.diffview.view.workspace.action")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")

    local st = workspace_state.get(tabnr)
    local lyt = workspace_view.get_layout(tabnr)
    if st and lyt then
      workspace_action.close({ layout = lyt, state = st })
    end
  elseif tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_action = require("era.m.diffview.view.commits.action")
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")

    local st = commits_state.get(tabnr)
    local lyt = commits_view.get_layout(tabnr)
    if st and lyt then
      commits_action.close({ layout = lyt, state = st })
    end
  end
end

---Refresh current diffview
function M.refresh()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local tabtype = vim.t[tabnr].tabtype

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local workspace_action = require("era.m.diffview.view.workspace.action")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")

    local st = workspace_state.get(tabnr)
    local lyt = workspace_view.get_layout(tabnr)
    if st and lyt then
      stl.async.run(function()
        workspace_action.refresh({ layout = lyt, state = st })
      end)
    end
  elseif tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_action = require("era.m.diffview.view.commits.action")
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")

    local st = commits_state.get(tabnr)
    local lyt = commits_view.get_layout(tabnr)
    if st and lyt then
      stl.async.run(function()
        commits_action.refresh({ layout = lyt, state = st })
      end)
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Git subscription for auto-refresh (workspace only)
----------------------------------------------------------------------------------------------------

local GIT_REFRESH_DEBOUNCE_MS = 300 ---@type integer

---Setup git subscription for auto-refresh on index changes
---@param st                          era.m.diffview.view.workspace.State
---@param ctx                         era.m.diffview.view.workspace.IContext
function M.__setup_git_subscription_workspace__(st, ctx)
  local tabnr = ctx.layout.tabnr ---@type integer
  local refreshing = false ---@type boolean
  local pending = false ---@type boolean
  local workspace_action = require("era.m.diffview.view.workspace.action")
  local workspace_state = require("era.m.diffview.view.workspace.state")

  local debounced_refresh ---@type stl.timer.IDisposableCallable
  debounced_refresh = stl.timer.debounce(function()
    if refreshing then
      pending = true
      return
    end

    -- Validate tab still exists and state is still active
    if not vim.api.nvim_tabpage_is_valid(tabnr) then
      return
    end
    if workspace_state.get(tabnr) ~= st then
      return
    end

    refreshing = true
    stl.async.run(function()
      -- Re-check state validity after async operation
      if workspace_state.get(tabnr) ~= st then
        refreshing = false
        return
      end

      workspace_action.refresh(ctx)
      refreshing = false
      if pending then
        pending = false
        -- Schedule immediate refresh instead of debouncing again
        vim.schedule(function()
          if vim.api.nvim_tabpage_is_valid(tabnr) and workspace_state.get(tabnr) == st then
            debounced_refresh()
          end
        end)
      end
    end)
  end, GIT_REFRESH_DEBOUNCE_MS)

  -- Subscribe to staged files changes (triggered by .git/index watcher)
  local subscription = era.m.git.state.o_staged_files:subscribe(
    stl.c.Subscriber.new({
      on_next = function()
        debounced_refresh()
      end,
    }),
    true -- ignoreInitial: avoid triggering on subscribe
  )

  st:set_git_subscription(subscription, debounced_refresh)
end

----------------------------------------------------------------------------------------------------
-- Keymap list for help display
----------------------------------------------------------------------------------------------------

---Get all keymaps for help display (for current tab)
---@return stl.t.IKeymap[]
function M.get_help_keymaps()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local tabtype = vim.t[tabnr].tabtype

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local workspace_keymap = require("era.m.diffview.view.workspace.keymap")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")

    local st = workspace_state.get(tabnr)
    local lyt = workspace_view.get_layout(tabnr)
    if st and lyt then
      return workspace_keymap.get_help_keymaps({ layout = lyt, state = st })
    end
  elseif tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_keymap = require("era.m.diffview.view.commits.keymap")
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")

    local st = commits_state.get(tabnr)
    local lyt = commits_view.get_layout(tabnr)
    if st and lyt then
      return commits_keymap.get_help_keymaps({ layout = lyt, state = st })
    end
  end

  return {}
end

return M
