---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.cmd" ---@type string

---@class era.m.diffview.cmd
local M = {}

---@param ctx                            era.m.diffview.view.commits.IContext
function M.__setup_commits_signs__(ctx)
  local lyt = ctx.layout
  local st = ctx.state
  local commits_bufnr = lyt.commits_bufnr ---@type integer|nil
  if not commits_bufnr then
    return
  end

  local pane_commits = require("era.m.diffview.pane.commits")
  pane_commits.clear_signs(commits_bufnr)
  local scheduler_lnum_present = stl.c.Scheduler.new({
    name = string.format("diffview:commits#%d#lnum_present", lyt.tabnr),
    mode = "debounce",
    delay = 64,
    timeout = 0,
    silent = stl.fn.truthy,
    value = stl.c.Observable.from_value(true),
    task = function()
      if vim.api.nvim_buf_is_valid(commits_bufnr) then
        pane_commits.update_sign_present(commits_bufnr, st:get_lnum_present())
      end
    end,
  })
  st:set_sign_scheduler(scheduler_lnum_present)
  stl.fn.observe({ st.lnum_present }, function()
    st:schedule_sign_present()
  end)
end

----------------------------------------------------------------------------------------------------
-- Command implementations: workspace (Git Diff)
----------------------------------------------------------------------------------------------------

---Open the Git workspace with Changes, History, and side-by-side preview.
---@param opts                        { layout: integer|nil }|nil
function M.open(opts)
  local commits_action = require("era.m.diffview.view.commits.action")
  local commits_state = require("era.m.diffview.view.commits.state")
  local workspace_keymap = require("era.m.diffview.view.workspace.keymap")
  local workspace_state = require("era.m.diffview.view.workspace.state")
  local workspace_tabline = require("era.m.diffview.view.workspace.tabline")
  local workspace_view = require("era.m.diffview.view.workspace.view")
  local workspace_winline = require("era.m.diffview.view.workspace.winline")

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
  local st = workspace_state.create(lyt.tabnr, dot.context.diffview.flag_fold_unchanges:snapshot())
  local history_state = commits_state.create(lyt.tabnr, dot.context.diffview.flag_fold_unchanges:snapshot())
  local history_ctx = workspace_view.history_context(lyt, st, history_state)

  ---@type era.m.diffview.view.workspace.IContext
  local ctx = {
    layout = lyt,
    state = st,
    history = history_ctx,
  }

  -- Setup keymaps
  workspace_keymap.setup_changes(ctx)
  workspace_keymap.setup_history(ctx)
  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    workspace_keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(lyt.sbs_left_winnr))
  end
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    workspace_keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(lyt.sbs_right_winnr))
  end

  -- Setup git subscription for auto-refresh
  M.__setup_git_subscription_workspace__(st, ctx)
  M.__setup_changes_resize_workspace__(st, ctx)
  M.__setup_commits_signs__(history_ctx)
  workspace_winline.setup(history_ctx)

  -- Fetch and render data
  st:request_refresh(function()
    -- Auto-select first entry if any
    local entries = workspace_view.get_visible_entries(st:get_entries())
    if #entries > 0 then
      local first_entry = entries[1] ---@type era.m.diffview.IFileEntry

      -- Select the first visible entry in panel order: Staged, then Unstaged.
      local pane_changes = require("era.m.diffview.pane.changes")
      local selected_visible = false
      for _, pane in ipairs(workspace_view.get_changes_panes(lyt)) do
        if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
          local line_map = pane_changes.get_line_map(pane.bufnr)
          if line_map then
            for i, item in ipairs(line_map) do
              if item.type == "file" and item.entry ~= nil then
                local visible_entry = assert(item.entry) ---@type era.m.diffview.IFileEntry
                first_entry = st:find_entry(visible_entry.filepath, visible_entry.stage_type) or visible_entry
                if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
                  vim.api.nvim_win_set_cursor(pane.winnr, { i, 0 })
                  vim.api.nvim_set_current_win(pane.winnr)
                end
                selected_visible = true
                break
              end
            end
          end
        end
        if selected_visible then
          break
        end
      end

      st:set_current_entry(first_entry)
      workspace_view.open_entry(ctx, first_entry)
    end
  end)

  stl.async.run(function()
    if not commits_action.refresh(history_ctx) then
      return
    end
    local commits = history_state:get_commits()
    local first_commit = commits[1] ---@type era.m.diffview.ICommit|nil
    if first_commit then
      history_state:set_current_commit(first_commit)
      local line_map = require("era.m.diffview.pane.commits").get_line_map(lyt.history.commits_bufnr)
      history_state:set_lnum_present(
        line_map and require("era.m.diffview.pane.commits").find_commit_line(line_map, first_commit.hash) or 1
      )
      history_state:schedule_sign_present()
    end
  end)
end

---Re-render on Changes width changes and resync content-fit heights after terminal height changes.
---@param st                          era.m.diffview.view.workspace.State
---@param ctx                         era.m.diffview.view.workspace.IContext
function M.__setup_changes_resize_workspace__(st, ctx)
  local workspace_view = require("era.m.diffview.view.workspace.view")
  local function get_changes_measurement()
    local winnrs = {} ---@type string[]
    local widths = {} ---@type string[]
    local width = nil ---@type integer|nil
    for _, pane in ipairs(workspace_view.get_changes_panes(ctx.layout)) do
      if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
        local pane_width = vim.api.nvim_win_get_width(pane.winnr) ---@type integer
        winnrs[#winnrs + 1] = tostring(pane.winnr)
        widths[#widths + 1] = tostring(pane_width)
        width = width or pane_width
      end
    end
    return table.concat(winnrs, "|"), table.concat(widths, "|"), width
  end
  local last_winnr_signature, last_width_signature = get_changes_measurement()
  local last_columns = vim.api.nvim_get_option_value("columns", {}) ---@type integer
  local last_lines = vim.api.nvim_get_option_value("lines", {}) ---@type integer

  local autocmd_id = vim.api.nvim_create_autocmd("WinResized", {
    callback = function()
      if st:is_disposed() then
        return
      end

      local columns = vim.api.nvim_get_option_value("columns", {}) ---@type integer
      local terminal_width_resized = columns ~= last_columns ---@type boolean
      last_columns = columns
      local lines = vim.api.nvim_get_option_value("lines", {}) ---@type integer
      local terminal_height_resized = lines ~= last_lines ---@type boolean
      last_lines = lines

      local winnr_signature, width_signature, width = get_changes_measurement()
      if winnr_signature == last_winnr_signature and width_signature == last_width_signature then
        if terminal_height_resized then
          workspace_view.sync_changes_heights(ctx.layout)
        end
        return
      end

      local same_windows = winnr_signature == last_winnr_signature ---@type boolean
      last_winnr_signature = winnr_signature
      last_width_signature = width_signature
      if winnr_signature == "" then
        return
      end
      -- A rebuilt pane inherits the preference; its clamped width is not a user resize.
      if same_windows and not terminal_width_resized and width then
        dot.context.diffview.panel_width:next(width)
      end
      workspace_view.render_changes(ctx)
    end,
  })
  st:set_resize_autocmd(autocmd_id)
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
    if
      vim.api.nvim_tabpage_is_valid(tabnr)
      and vim.t[tabnr].tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS
    then
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
  local st = commits_state.create(lyt.tabnr, dot.context.diffview.flag_fold_unchanges:snapshot())

  -- Set path filter if provided
  if path_filter then
    st:set_path_filter(path_filter)
  end

  ---@type era.m.diffview.view.commits.IContext
  local ctx = {
    layout = lyt,
    state = st,
  }

  M.__setup_commits_signs__(ctx)

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
    if not commits_action.refresh(ctx) then
      return
    end

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
    local commits_action = require("era.m.diffview.view.commits.action")
    local commits_state = require("era.m.diffview.view.commits.state")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")

    local st = workspace_state.get(tabnr)
    local lyt = workspace_view.get_layout(tabnr)
    if st and lyt then
      st:request_refresh()
      local history_state = commits_state.get(tabnr)
      if history_state then
        local history_ctx = workspace_view.history_context(lyt, st, history_state)
        stl.async.run(function()
          commits_action.refresh(history_ctx)
        end)
      end
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

---Setup git subscription for auto-refresh on index changes
---@param st                          era.m.diffview.view.workspace.State
---@param ctx                         era.m.diffview.view.workspace.IContext
function M.__setup_git_subscription_workspace__(st, ctx)
  local tabnr = ctx.layout.tabnr ---@type integer
  local data = require("era.m.diffview.data")
  local workspace_action = require("era.m.diffview.view.workspace.action")
  local Refresh = require("era.m.diffview.view.workspace.refresh")
  local workspace_state = require("era.m.diffview.view.workspace.state")

  local refresh = Refresh.new({
    is_stale = function()
      return not data.matches_status_entries(st:get_entries(), era.m.git.state.status_table())
    end,
    is_valid = function()
      return vim.api.nvim_tabpage_is_valid(tabnr) and workspace_state.get(tabnr) == st
    end,
    run = function(token)
      if workspace_state.get(tabnr) ~= st then
        return
      end
      workspace_action.refresh(ctx, token)
    end,
  })
  st:set_refresh(refresh)

  -- Index-only snapshots carry enough blob identity to absorb the originating view's event.
  -- Broader refreshes may include worktree changes, whose raw target object is unavailable.
  local subscription = era.m.git.state.o_refreshed:subscribe(
    stl.c.Subscriber.new({
      on_next = function(event)
        if event.change_scope == "index" then
          st:request_refresh_if_stale()
        else
          st:request_refresh()
        end
      end,
    }),
    true -- ignoreInitial: avoid triggering on subscribe
  )

  st:set_git_subscription(subscription)
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
      local history_state = require("era.m.diffview.view.commits.state").get(tabnr)
      local history = history_state and workspace_view.history_context(lyt, st, history_state) or nil
      return workspace_keymap.get_help_keymaps({ layout = lyt, state = st, history = history })
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
