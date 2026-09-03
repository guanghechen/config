---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.fn" ---@type string

local S = era.m.diffview

---@class era.m.diffview.fn
local M = {}

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---Open the repository Git workspace.
---@param opts                        { layout: integer|nil }|nil
function M.open_workspace(opts)
  S.cmd.open(opts)
end

---Open File History view (opens commits view with path filter)
---@param opts                        { filepath: string|nil, layout: integer|nil }|nil
function M.open_file_history(opts)
  local filepath = opts and opts.filepath ---@type string|nil
  local layout = opts and opts.layout ---@type integer|nil

  if not filepath then
    -- Use current buffer file
    local bufnr = vim.api.nvim_get_current_buf()
    filepath = vim.api.nvim_buf_get_name(bufnr)
  end

  if not filepath or filepath == "" then
    stl.reporter.warn({
      from = __module_name__,
      subject = "open_file_history",
      message = "No file specified",
    })
    return
  end

  local workspace = dot.path.workspace()
  if not workspace then
    stl.reporter.warn({
      from = __module_name__,
      subject = "open_file_history",
      message = "Not in a git repository",
    })
    return
  end

  -- Get relative path
  local relative = stl.os.path.relative(workspace, filepath)

  -- Call commits with path filter
  S.cmd.log({
    layout = layout,
    path = relative,
  })
end

---Open commits view (git log)
---@param opts                        { layout: integer|nil, path: string|nil }|nil
function M.open_commits(opts)
  S.cmd.log(opts)
end

---Close current Diffview
function M.close()
  S.cmd.close()
end

---Refresh current Diffview
function M.refresh()
  S.cmd.refresh()
end

---Handle window navigation that depends on the active Diffview layout.
---@param direction                    "h"|"j"|"k"|"l"
---@return boolean
function M.navigate_window(direction)
  if direction ~= "h" then
    return false
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  if vim.t[tabnr].tabtype ~= stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    return false
  end

  local workspace_view = require("era.m.diffview.view.workspace.view")
  local lyt = workspace_view.get_layout(tabnr)
  if not lyt or vim.api.nvim_get_current_win() ~= lyt.sbs_left_winnr then
    return false
  end
  return workspace_view.focus_changes(lyt)
end

---Reveal the active item in the view's navigation panel, or hide that panel when already focused.
function M.reveal()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local workspace_action = require("era.m.diffview.view.workspace.action")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")

    local st = workspace_state.get(tabnr)
    local lyt = workspace_view.get_layout(tabnr)
    if not st or not lyt then
      return
    end
    local history_state = require("era.m.diffview.view.commits.state").get(tabnr)
    local history = history_state and workspace_view.history_context(lyt, st, history_state) or nil
    workspace_action.reveal({ layout = lyt, state = st, history = history })
  elseif tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_action = require("era.m.diffview.view.commits.action")
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")

    local st = commits_state.get(tabnr)
    local lyt = commits_view.get_layout(tabnr)
    if not st or not lyt then
      return
    end
    commits_action.reveal({ layout = lyt, state = st })
  end
end

---Toggle repository History in workspace or commits in the standalone log view.
function M.toggle_commits()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")
    local workspace_keymap = require("era.m.diffview.view.workspace.keymap")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")

    local st = workspace_state.get(tabnr)
    local history_state = commits_state.get(tabnr)
    local lyt = workspace_view.get_layout(tabnr)
    if st and history_state and lyt then
      local history = workspace_view.history_context(lyt, st, history_state)
      local ctx = { layout = lyt, state = st, history = history } ---@type era.m.diffview.view.workspace.IContext
      workspace_view.toggle_history(lyt)
      if lyt.history.commits_winnr and vim.api.nvim_win_is_valid(lyt.history.commits_winnr) then
        workspace_keymap.setup_history(ctx)
        commits_view.render_commits(history)
        workspace_view.focus_history(lyt)
      end
    end
  elseif tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")

    local st = commits_state.get(tabnr)
    local lyt = commits_view.get_layout(tabnr)
    if st and lyt then
      local ctx = { layout = lyt, state = st } ---@type era.m.diffview.view.commits.IContext
      commits_view.toggle_commits(ctx)
      -- Re-render if shown
      if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
        commits_view.render_commits(ctx)
        vim.api.nvim_set_current_win(lyt.commits_winnr)
      end
    end
  end
end

---Toggle the workspace sidebar or the standalone commits filetree.
function M.toggle_files()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local commits_view = require("era.m.diffview.view.commits.view")
    local workspace_keymap = require("era.m.diffview.view.workspace.keymap")
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")

    local st = workspace_state.get(tabnr)
    local lyt = workspace_view.get_layout(tabnr)
    if st and lyt then
      local history_state = require("era.m.diffview.view.commits.state").get(tabnr)
      local history = history_state and workspace_view.history_context(lyt, st, history_state) or nil
      local ctx = { layout = lyt, state = st, history = history } ---@type era.m.diffview.view.workspace.IContext
      local _, sidebar_visible = workspace_view.toggle_sidebar(lyt)
      if sidebar_visible then
        workspace_keymap.setup_changes(ctx)
        workspace_view.render_changes(ctx)
        if history then
          workspace_keymap.setup_history(ctx)
          commits_view.render_commits(history)
        end
        local current = st:get_current_entry()
        workspace_view.focus_changes(lyt, current and current.stage_type or nil)
      end
    end
  elseif tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")

    local st = commits_state.get(tabnr)
    local lyt = commits_view.get_layout(tabnr)
    if st and lyt then
      local ctx = { layout = lyt, state = st } ---@type era.m.diffview.view.commits.IContext
      commits_view.toggle_filetree(ctx)
      -- Re-render if shown
      if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
        commits_view.render_filetree(ctx)
        vim.api.nvim_set_current_win(lyt.filetree_winnr)
      end
    end
  end
end

return M
