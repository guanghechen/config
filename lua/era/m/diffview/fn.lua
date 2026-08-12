---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.fn" ---@type string

local S = era.m.diffview

---@class era.m.diffview.fn
local M = {}

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---Open workspace view (staged/unstaged)
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
  local relative = yoz.path.relative(workspace, filepath, false, "/")

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

---Toggle commits panel visibility (for commits view)
function M.toggle_commits()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_COMMITS then
    local commits_state = require("era.m.diffview.view.commits.state")
    local commits_view = require("era.m.diffview.view.commits.view")

    local st = commits_state.get(tabnr)
    local lyt = commits_view.get_layout(tabnr)
    if st and lyt then
      commits_view.toggle_commits(lyt)
      -- Re-render if shown
      if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
        commits_view.render_commits({
          layout = lyt,
          state = st,
        })
        vim.api.nvim_set_current_win(lyt.commits_winnr)
      end
    end
  end
  -- DIFFVIEW_WORKSPACE doesn't have a commits panel
end

---Toggle files panel visibility (changes for workspace, filetree for commits)
function M.toggle_files()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil

  if tabtype == stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE then
    local workspace_state = require("era.m.diffview.view.workspace.state")
    local workspace_view = require("era.m.diffview.view.workspace.view")

    local st = workspace_state.get(tabnr)
    local lyt = workspace_view.get_layout(tabnr)
    if st and lyt then
      workspace_view.toggle_changes(lyt)
      -- Re-render if shown
      local changes_visible = false
      for _, pane in ipairs(workspace_view.get_changes_panes(lyt)) do
        if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
          changes_visible = true
          break
        end
      end
      if changes_visible then
        local ctx = {
          layout = lyt,
          state = st,
        }
        require("era.m.diffview.view.workspace.keymap").setup_changes(ctx)
        workspace_view.render_changes(ctx)
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
      commits_view.toggle_filetree(lyt)
      -- Re-render if shown
      if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
        commits_view.render_filetree({
          layout = lyt,
          state = st,
        })
        vim.api.nvim_set_current_win(lyt.filetree_winnr)
      end
    end
  end
end

return M
