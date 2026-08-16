---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.commits.action" ---@type string

local config = require("era.m.diffview.config")
local data = require("era.m.diffview.data")
local pane_commits = require("era.m.diffview.pane.commits")
local pane_sbs = require("era.m.diffview.pane.sbs")
local commits_state = require("era.m.diffview.view.commits.state")
local commits_view = require("era.m.diffview.view.commits.view")

---Commits view actions.
---@class era.m.diffview.view.commits.action
local M = {}

----------------------------------------------------------------------------------------------------
-- Local helpers
----------------------------------------------------------------------------------------------------

---Get current buffer and cursor line number
---@return integer bufnr, integer lnum
local function get_cursor_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local lnum = vim.api.nvim_win_get_cursor(winnr)[1]
  return bufnr, lnum
end

---Get item at cursor in commits pane
---@return era.m.diffview.ICommitsLineMap|nil
local function get_item_at_cursor()
  local bufnr, lnum = get_cursor_info()
  return pane_commits.get_item_at_line(bufnr, lnum)
end

---Update lnum_present based on commit hash
---@param ctx                            era.m.diffview.view.commits.IContext
---@param hash                           string
local function update_lnum_present(ctx, hash)
  local lyt = ctx.layout

  if not lyt.commits_bufnr or not vim.api.nvim_buf_is_valid(lyt.commits_bufnr) then
    return
  end

  local line_map = pane_commits.get_line_map(lyt.commits_bufnr)
  if not line_map then
    return
  end

  local lnum = pane_commits.find_commit_line(line_map, hash)
  if lnum then
    ctx.state:set_lnum_present(lnum)
  end
end

---Find the authoritative commit object in state by hash.
---@param ctx                            era.m.diffview.view.commits.IContext
---@param hash                           string
---@return era.m.diffview.ICommit|nil
local function find_commit_in_state(ctx, hash)
  for _, c in ipairs(ctx.state:get_commits()) do
    if c.hash == hash then
      return c
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------
-- Selection actions
----------------------------------------------------------------------------------------------------

---Set commit at cursor as active commit (displayed in sbs)
---@param ctx                            era.m.diffview.view.commits.IContext
function M.set_active_commit(ctx)
  local item = get_item_at_cursor()
  if not item or not item.commit then
    return
  end

  local actual_commit = find_commit_in_state(ctx, item.commit.hash)
  if not actual_commit then
    return
  end

  ctx.state:set_current_commit(actual_commit)
  update_lnum_present(ctx, actual_commit.hash)
  dot.state.status.dirtier_tabline:mark_dirty()

  -- If cursor is on a file entry, also select that file and show diff
  if item.type == "file" and item.entry then
    ctx.state:set_current_entry(item.entry)
    stl.async.run(function()
      commits_view.open_entry(ctx, actual_commit, item.entry)
    end)
  elseif ctx.layout.layout_type == 5 then
    -- Layout 5: load files if needed and render filetree
    if not actual_commit.files then
      stl.async.run(function()
        M.__load_commit_files_and_render_filetree__(ctx, actual_commit)
      end)
    else
      commits_view.render_filetree(ctx)
    end
  else
    commits_view.clear_sbs(ctx)
  end
end

---Select item at cursor in commits panel
---@param ctx                            era.m.diffview.view.commits.IContext
function M.select(ctx)
  local item = get_item_at_cursor()
  if not item then
    return
  end

  if item.type == "commit" and item.commit then
    -- In file history mode (path_filter set), directly open target file diff
    local path_filter = ctx.state:get_path_filter()
    if path_filter then
      M.__open_target_file_diff__(ctx, item.commit, path_filter)
      return
    end

    -- In layout 5 (commits_filetree), selecting a commit updates filetree
    if ctx.layout.layout_type == 5 then
      M.__select_commit_for_filetree__(ctx, item.commit)
    else
      -- Toggle expand/collapse for commit in other layouts
      M.toggle_expand(ctx)
    end
  elseif item.type == "file" and item.commit and item.entry then
    -- Open file in side-by-side view
    M.view_diff(ctx)
  end
end

---View diff at cursor
---@param ctx                            era.m.diffview.view.commits.IContext
function M.view_diff(ctx)
  local item = get_item_at_cursor()
  if not item then
    return
  end

  if item.type == "commit" and item.commit then
    -- Expand commit first if not expanded
    if not ctx.state:is_commit_expanded(item.commit.hash) then
      stl.async.run(function()
        M.__expand_commit__(ctx, item.commit)
      end)
    end
  elseif item.type == "file" and item.commit and item.entry then
    -- Open file in side-by-side view
    ctx.state:set_current_commit(item.commit)
    ctx.state:set_current_entry(item.entry)
    update_lnum_present(ctx, item.commit.hash)
    dot.state.status.dirtier_tabline:mark_dirty()

    stl.async.run(function()
      commits_view.open_entry(ctx, item.commit, item.entry)
    end)
  end
end

----------------------------------------------------------------------------------------------------
-- Expansion actions
----------------------------------------------------------------------------------------------------

---Toggle commit expansion at cursor
---@param ctx                            era.m.diffview.view.commits.IContext
function M.toggle_expand(ctx)
  local item = get_item_at_cursor()
  if not item or item.type ~= "commit" or not item.commit then
    return
  end

  local is_expanded = ctx.state:is_commit_expanded(item.commit.hash)
  if is_expanded then
    -- Collapse
    ctx.state:toggle_commit_expanded(item.commit.hash)
    commits_view.render_commits(ctx)
  else
    -- Expand and load files
    stl.async.run(function()
      M.__expand_commit__(ctx, item.commit)
    end)
  end
end

---Expand commit at cursor
---@param ctx                            era.m.diffview.view.commits.IContext
function M.expand(ctx)
  local item = get_item_at_cursor()
  if not item or item.type ~= "commit" or not item.commit then
    return
  end

  if not ctx.state:is_commit_expanded(item.commit.hash) then
    stl.async.run(function()
      M.__expand_commit__(ctx, item.commit)
    end)
  end
end

---Collapse commit at cursor
---@param ctx                            era.m.diffview.view.commits.IContext
function M.collapse(ctx)
  local item = get_item_at_cursor()
  if not item or item.type ~= "commit" or not item.commit then
    return
  end

  if ctx.state:is_commit_expanded(item.commit.hash) then
    ctx.state:toggle_commit_expanded(item.commit.hash)
    commits_view.render_commits(ctx)
  end
end

---Expand all commits
---@param ctx                            era.m.diffview.view.commits.IContext
function M.expand_all(ctx)
  stl.async.run(function()
    local commits = ctx.state:get_commits()

    -- Load files for commits that don't have them yet
    for _, commit in stl.async.ipairs(commits) do
      if not commit.files then
        commit.files = data.fetch_commit_files(commit.hash)
      end
    end

    -- Expand all commits
    stl.async.scheduler()
    ctx.state:expand_all()
    commits_view.render_commits(ctx)
  end)
end

---Collapse all commits
---@param ctx                            era.m.diffview.view.commits.IContext
function M.collapse_all(ctx)
  ctx.state:collapse_all()
  commits_view.render_commits(ctx)
end

----------------------------------------------------------------------------------------------------
-- Navigation actions
----------------------------------------------------------------------------------------------------

---Move to next item in commits panel
---@param _                             era.m.diffview.view.commits.IContext
function M.next(_)
  local winnr = vim.api.nvim_get_current_win()
  local lnum = vim.api.nvim_win_get_cursor(winnr)[1]
  local bufnr = vim.api.nvim_get_current_buf()
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if lnum < line_count then
    vim.api.nvim_win_set_cursor(winnr, { lnum + 1, 0 })
  end
end

---Move to previous item in commits panel
---@param _                             era.m.diffview.view.commits.IContext
function M.prev(_)
  local winnr = vim.api.nvim_get_current_win()
  local lnum = vim.api.nvim_win_get_cursor(winnr)[1]

  if lnum > 1 then
    vim.api.nvim_win_set_cursor(winnr, { lnum - 1, 0 })
  end
end

---Go to next page
---@param ctx                            era.m.diffview.view.commits.IContext
function M.next_page(ctx)
  local page = ctx.state:get_commits_page()
  local page_count = ctx.state:get_commits_page_count()

  if page >= page_count then
    return
  end

  local next_page = page + 1
  ctx.state:set_commits_page(next_page)

  -- Clear expanded commits when switching pages
  ctx.state.expanded_commits:next({})

  stl.async.run(function()
    M.__refresh_page__(ctx, next_page)
  end)
end

---Go to previous page
---@param ctx                            era.m.diffview.view.commits.IContext
function M.prev_page(ctx)
  local page = ctx.state:get_commits_page()

  if page <= 1 then
    return
  end

  local prev_page = page - 1
  ctx.state:set_commits_page(prev_page)

  -- Clear expanded commits when switching pages
  ctx.state.expanded_commits:next({})

  stl.async.run(function()
    M.__refresh_page__(ctx, prev_page)
  end)
end

---Navigate to next commit diff (from any window)
---@param ctx                            era.m.diffview.view.commits.IContext
function M.goto_next_commit(ctx)
  local commits = ctx.state:get_commits()
  local current = ctx.state:get_current_commit()

  if #commits == 0 then
    return
  end

  local current_idx = 0
  if current then
    for i, c in ipairs(commits) do
      if c.hash == current.hash then
        current_idx = i
        break
      end
    end
  end

  local next_idx = current_idx + 1
  if next_idx > #commits then
    next_idx = 1
  end

  local next_commit = commits[next_idx]
  ctx.state:set_current_commit(next_commit)
  update_lnum_present(ctx, next_commit.hash)
  dot.state.status.dirtier_tabline:mark_dirty()

  -- Update commits cursor
  M.__update_commits_cursor__(ctx, next_commit.hash)

  -- Clear the diff view (user needs to select file)
  commits_view.clear_sbs(ctx)
end

---Navigate to previous commit diff (from any window)
---@param ctx                            era.m.diffview.view.commits.IContext
function M.goto_prev_commit(ctx)
  local commits = ctx.state:get_commits()
  local current = ctx.state:get_current_commit()

  if #commits == 0 then
    return
  end

  local current_idx = 0
  if current then
    for i, c in ipairs(commits) do
      if c.hash == current.hash then
        current_idx = i
        break
      end
    end
  end

  local prev_idx = current_idx - 1
  if prev_idx < 1 then
    prev_idx = #commits
  end

  local prev_commit = commits[prev_idx]
  ctx.state:set_current_commit(prev_commit)
  update_lnum_present(ctx, prev_commit.hash)
  dot.state.status.dirtier_tabline:mark_dirty()

  -- Update commits cursor
  M.__update_commits_cursor__(ctx, prev_commit.hash)

  -- Clear the diff view (user needs to select file)
  commits_view.clear_sbs(ctx)
end

----------------------------------------------------------------------------------------------------
-- Utility actions
----------------------------------------------------------------------------------------------------

---Yank commit hash at cursor to clipboard
---@param _                             era.m.diffview.view.commits.IContext
function M.yank_hash(_)
  local item = get_item_at_cursor()
  if not item or not item.commit then
    return
  end

  local hash = item.commit.hash
  stl.nvim.fn.copy(hash)
  stl.reporter.info({
    from = __module_name__,
    subject = "yank",
    message = string.format("Copied commit hash: %s", item.commit.abbrev_hash),
  })
end

---Show commit details in popup
---@param _                             era.m.diffview.view.commits.IContext
function M.show_details(_)
  local item = get_item_at_cursor()
  if not item or not item.commit then
    return
  end

  local commit = item.commit ---@type era.m.diffview.ICommit
  local hash = commit.hash
  local abbrev_hash = commit.abbrev_hash

  stl.async.run(function()
    -- Fetch full commit details
    local result = stl.git.exec
      .exec({
        "show",
        "--no-patch",
        "--format=fuller",
        hash,
      }, nil, nil)
      :await()

    if result.code ~= 0 then
      stl.async.scheduler()
      stl.reporter.warn({
        from = __module_name__,
        subject = "show_details",
        message = "Failed to get commit details",
      })
      return
    end

    stl.async.scheduler()
    M.__show_commit_popup__(abbrev_hash, result.lines)
  end)
end

---Restore file to commit version
---@param ctx                            era.m.diffview.view.commits.IContext
function M.restore_file(ctx)
  local item = get_item_at_cursor()
  if not item then
    return
  end

  local commit = item.commit
  local entry = item.entry

  if not commit or not entry then
    return
  end

  local filepath = entry.filepath
  local full_path = dot.path.join(dot.path.workspace(), filepath)

  -- Confirmation dialog
  vim.ui.select({ "Yes", "No" }, {
    prompt = string.format("Restore %s to commit %s?", filepath, commit.abbrev_hash),
  }, function(choice)
    if choice ~= "Yes" then
      return
    end

    -- Restore file using git show
    stl.git.exec.exec_async(
      { "show", commit.hash .. ":" .. filepath },
      { cwd = dot.path.workspace() },
      function(lines, code)
        if code ~= 0 then
          stl.reporter.warn({
            from = __module_name__,
            subject = "restore_file",
            message = "Failed to get file content from commit",
          })
          return
        end

        -- Write to file
        vim.schedule(function()
          local ok, err = pcall(vim.fn.writefile, lines, full_path)
          if ok then
            stl.reporter.info({
              from = __module_name__,
              subject = "restore_file",
              message = string.format("Restored %s to commit %s", filepath, commit.abbrev_hash),
            })
            -- Refresh to show changes
            stl.async.run(function()
              M.refresh(ctx)
            end)
          else
            stl.reporter.error({
              from = __module_name__,
              subject = "restore_file",
              message = "Failed to write file: " .. tostring(err),
            })
          end
        end)
      end
    )
  end)
end

----------------------------------------------------------------------------------------------------
-- Focus actions
----------------------------------------------------------------------------------------------------

---Focus commits panel
---@param ctx                            era.m.diffview.view.commits.IContext
function M.focus_commits(ctx)
  commits_view.focus_commits(ctx.layout)
end

---Focus filetree panel
---@param ctx                            era.m.diffview.view.commits.IContext
function M.focus_filetree(ctx)
  commits_view.focus_filetree(ctx.layout)
end

---Focus left sbs window
---@param ctx                            era.m.diffview.view.commits.IContext
function M.focus_left(ctx)
  commits_view.focus_left(ctx.layout)
end

---Focus right sbs window
---@param ctx                            era.m.diffview.view.commits.IContext
function M.focus_right(ctx)
  commits_view.focus_right(ctx.layout)
end

---Cycle focus between panels
---@param ctx                            era.m.diffview.view.commits.IContext
function M.cycle_focus(ctx)
  commits_view.cycle_focus(ctx.layout)
end

----------------------------------------------------------------------------------------------------
-- Panel visibility
----------------------------------------------------------------------------------------------------

---Toggle commits panel visibility
---@param ctx                            era.m.diffview.view.commits.IContext
function M.toggle_commits(ctx)
  ctx.layout = commits_view.toggle_commits(ctx.layout)
  commits_view.set_layout(ctx.layout.tabnr, ctx.layout)
end

---Toggle filetree panel visibility
---@param ctx                            era.m.diffview.view.commits.IContext
function M.toggle_filetree(ctx)
  ctx.layout = commits_view.toggle_filetree(ctx.layout)
  commits_view.set_layout(ctx.layout.tabnr, ctx.layout)
end

----------------------------------------------------------------------------------------------------
-- Fold actions (for sbs windows)
----------------------------------------------------------------------------------------------------

---@type table<string, string>
local FOLD_ACTIONS = {
  toggle = "za",
  open = "zo",
  close = "zc",
  open_all = "zR",
  close_all = "zM",
}

---Execute fold action
---@param action                         "toggle"|"open"|"close"|"open_all"|"close_all"
local function execute_fold(action)
  local cmd = FOLD_ACTIONS[action]
  if cmd then
    vim.cmd("normal! " .. cmd)
  end
end

---Toggle fold at cursor
---@param _                             era.m.diffview.view.commits.IContext
function M.toggle_fold(_)
  execute_fold("toggle")
end

---Open fold at cursor
---@param _                             era.m.diffview.view.commits.IContext
function M.open_fold(_)
  execute_fold("open")
end

---Close fold at cursor
---@param _                             era.m.diffview.view.commits.IContext
function M.close_fold(_)
  execute_fold("close")
end

---Open all folds
---@param _                             era.m.diffview.view.commits.IContext
function M.open_all_folds(_)
  execute_fold("open_all")
end

---Close all folds
---@param _                             era.m.diffview.view.commits.IContext
function M.close_all_folds(_)
  execute_fold("close_all")
end

----------------------------------------------------------------------------------------------------
-- SBS panel expand/collapse actions
----------------------------------------------------------------------------------------------------

---Toggle commit expand from sbs window
---@param ctx                            era.m.diffview.view.commits.IContext
function M.sbs_toggle_expand(ctx)
  local current = ctx.state:get_current_commit()
  if not current then
    return
  end

  local is_expanded = ctx.state:is_commit_expanded(current.hash)
  if is_expanded then
    ctx.state:toggle_commit_expanded(current.hash)
    commits_view.render_commits(ctx)
  else
    stl.async.run(function()
      M.__expand_commit__(ctx, current)
    end)
  end
end

---Expand commit from sbs window
---@param ctx                            era.m.diffview.view.commits.IContext
function M.sbs_expand(ctx)
  local current = ctx.state:get_current_commit()
  if not current then
    return
  end

  if not ctx.state:is_commit_expanded(current.hash) then
    stl.async.run(function()
      M.__expand_commit__(ctx, current)
    end)
  end
end

---Collapse commit from sbs window
---@param ctx                            era.m.diffview.view.commits.IContext
function M.sbs_collapse(ctx)
  local current = ctx.state:get_current_commit()
  if not current then
    return
  end

  if ctx.state:is_commit_expanded(current.hash) then
    ctx.state:toggle_commit_expanded(current.hash)
    commits_view.render_commits(ctx)
  end
end

---Expand all commits from sbs window
---@param ctx                            era.m.diffview.view.commits.IContext
function M.sbs_expand_all(ctx)
  M.expand_all(ctx)
end

---Collapse all commits from sbs window
---@param ctx                            era.m.diffview.view.commits.IContext
function M.sbs_collapse_all(ctx)
  M.collapse_all(ctx)
end

----------------------------------------------------------------------------------------------------
-- Flag toggles
----------------------------------------------------------------------------------------------------

---Toggle viewtype (tree/list) for commits pane
---@param ctx                            era.m.diffview.view.commits.IContext
function M.toggle_viewtype(ctx)
  local current = dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
  local next_viewtype = current == "tree" and "list" or "tree" ---@type stl.m.diffview.PanelViewTypeEnum
  dot.context.diffview.flag_panel_viewtype:next(next_viewtype)
  commits_view.render_commits(ctx)
end

---Toggle fold empty directories
---@param ctx                            era.m.diffview.view.commits.IContext
function M.toggle_foldempty(ctx)
  local current = dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
  dot.context.diffview.flag_foldempty:next(not current)
  commits_view.render_commits(ctx)
end

---Toggle folding unchanged hunks in sbs
---@param ctx                            era.m.diffview.view.commits.IContext
function M.toggle_fold_unchanged(ctx)
  local current = dot.context.diffview.flag_fold_unchanges:snapshot() ---@type boolean
  dot.context.diffview.flag_fold_unchanges:next(not current)

  local lyt = ctx.layout
  pane_sbs.apply_fold_unchanged_pair(lyt.sbs_left_winnr, lyt.sbs_right_winnr)
end

---Switch to specific layout directly
---@param ctx                            era.m.diffview.view.commits.IContext
---@param layout_type                    integer                         1-5
function M.switch_to_layout(ctx, layout_type)
  if layout_type < 1 or layout_type > 5 then
    return
  end

  local current_layout_type = ctx.layout.layout_type or 1
  if current_layout_type == layout_type then
    return
  end

  -- Save to context
  dot.context.diffview.commits_layout:next(layout_type)

  -- Switch layout
  local new_lyt = commits_view.switch_layout(ctx.layout, layout_type)
  commits_view.set_layout(ctx.layout.tabnr, new_lyt)
  ctx.layout = new_lyt

  -- Setup keymaps for new layout components
  local keymap = require("era.m.diffview.view.commits.keymap")
  if new_lyt.commits_bufnr then
    keymap.setup_commits(ctx)
  end
  if new_lyt.filetree_bufnr then
    keymap.setup_filetree(ctx)
  end
  if new_lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(new_lyt.sbs_left_winnr) then
    keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(new_lyt.sbs_left_winnr))
  end
  if new_lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(new_lyt.sbs_right_winnr) then
    keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(new_lyt.sbs_right_winnr))
  end

  -- Re-render and focus
  commits_view.render_commits(ctx)

  -- For layout 5 (commits_filetree), load files if needed and render filetree
  if new_lyt.filetree_bufnr then
    local current_commit = ctx.state:get_current_commit()

    -- If no current_commit, try to get commit from commits buffer line_map
    if not current_commit and new_lyt.commits_bufnr and vim.api.nvim_buf_is_valid(new_lyt.commits_bufnr) then
      -- Get cursor position in commits window, or default to line 1
      local lnum = 1 ---@type integer
      if new_lyt.commits_winnr and vim.api.nvim_win_is_valid(new_lyt.commits_winnr) then
        lnum = vim.api.nvim_win_get_cursor(new_lyt.commits_winnr)[1]
      end

      local item = pane_commits.get_item_at_line(new_lyt.commits_bufnr, lnum)
      if item and item.commit then
        -- Resolve against the authoritative state snapshot.
        local commits = ctx.state:get_commits()
        for _, c in ipairs(commits) do
          if c.hash == item.commit.hash then
            current_commit = c
            ctx.state:set_current_commit(current_commit)
            update_lnum_present(ctx, current_commit.hash)
            break
          end
        end
      end
    end

    if current_commit and not current_commit.files then
      -- Load files asynchronously then render filetree
      stl.async.run(function()
        M.__load_commit_files_and_render_filetree__(ctx, current_commit)
      end)
    else
      commits_view.render_filetree(ctx)
    end
  end

  if new_lyt.commits_winnr and vim.api.nvim_win_is_valid(new_lyt.commits_winnr) then
    commits_view.focus_commits(ctx.layout)
  end

  -- Update tabline
  dot.state.status.dirtier_tabline:mark_dirty()
end

---Cycle layout (1 -> 2 -> 3 -> 4 -> 5 -> 1)
---@param ctx                            era.m.diffview.view.commits.IContext
function M.cycle_layout(ctx)
  local current_layout_type = ctx.layout.layout_type or 1 ---@type integer
  local next_layout_type = (current_layout_type % 5) + 1 ---@type integer

  -- Save to context
  dot.context.diffview.commits_layout:next(next_layout_type)

  -- Switch layout
  local new_lyt = commits_view.switch_layout(ctx.layout, next_layout_type)

  commits_view.set_layout(ctx.layout.tabnr, new_lyt)
  ctx.layout = new_lyt

  -- Setup keymaps for new layout components
  local keymap = require("era.m.diffview.view.commits.keymap")
  if new_lyt.commits_bufnr then
    keymap.setup_commits(ctx)
  end
  if new_lyt.filetree_bufnr then
    keymap.setup_filetree(ctx)
  end
  if new_lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(new_lyt.sbs_left_winnr) then
    keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(new_lyt.sbs_left_winnr))
  end
  if new_lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(new_lyt.sbs_right_winnr) then
    keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(new_lyt.sbs_right_winnr))
  end

  -- Re-render and focus
  commits_view.render_commits(ctx)

  -- For layout 5 (commits_filetree), load files if needed and render filetree
  if new_lyt.filetree_bufnr then
    local current_commit = ctx.state:get_current_commit()

    -- If no current_commit, try to get commit from commits buffer line_map
    if not current_commit and new_lyt.commits_bufnr and vim.api.nvim_buf_is_valid(new_lyt.commits_bufnr) then
      -- Get cursor position in commits window, or default to line 1
      local lnum = 1 ---@type integer
      if new_lyt.commits_winnr and vim.api.nvim_win_is_valid(new_lyt.commits_winnr) then
        lnum = vim.api.nvim_win_get_cursor(new_lyt.commits_winnr)[1]
      end

      local item = pane_commits.get_item_at_line(new_lyt.commits_bufnr, lnum)

      if item and item.commit then
        -- Resolve against the authoritative state snapshot.
        local commits = ctx.state:get_commits()
        for _, c in ipairs(commits) do
          if c.hash == item.commit.hash then
            current_commit = c
            ctx.state:set_current_commit(current_commit)
            update_lnum_present(ctx, current_commit.hash)
            break
          end
        end
      end
    end

    if current_commit and not current_commit.files then
      -- Load files asynchronously then render filetree
      stl.async.run(function()
        M.__load_commit_files_and_render_filetree__(ctx, current_commit)
      end)
    else
      commits_view.render_filetree(ctx)
    end
  end

  if new_lyt.commits_winnr and vim.api.nvim_win_is_valid(new_lyt.commits_winnr) then
    commits_view.focus_commits(ctx.layout)
  end

  -- Update tabline
  dot.state.status.dirtier_tabline:mark_dirty()
end

---Previous layout (5 -> 4 -> 3 -> 2 -> 1 -> 5)
---@param ctx                            era.m.diffview.view.commits.IContext
function M.prev_layout(ctx)
  local current_layout_type = ctx.layout.layout_type or 1 ---@type integer
  local prev_layout_type = ((current_layout_type - 2) % 5) + 1 ---@type integer

  -- Save to context
  dot.context.diffview.commits_layout:next(prev_layout_type)

  -- Switch layout
  local new_lyt = commits_view.switch_layout(ctx.layout, prev_layout_type)

  commits_view.set_layout(ctx.layout.tabnr, new_lyt)
  ctx.layout = new_lyt

  -- Setup keymaps for new layout components
  local keymap = require("era.m.diffview.view.commits.keymap")
  if new_lyt.commits_bufnr then
    keymap.setup_commits(ctx)
  end
  if new_lyt.filetree_bufnr then
    keymap.setup_filetree(ctx)
  end
  if new_lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(new_lyt.sbs_left_winnr) then
    keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(new_lyt.sbs_left_winnr))
  end
  if new_lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(new_lyt.sbs_right_winnr) then
    keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(new_lyt.sbs_right_winnr))
  end

  -- Re-render and focus
  commits_view.render_commits(ctx)

  -- For layout 5 (commits_filetree), load files if needed and render filetree
  if new_lyt.filetree_bufnr then
    local current_commit = ctx.state:get_current_commit()

    -- If no current_commit, try to get commit from commits buffer line_map
    if not current_commit and new_lyt.commits_bufnr and vim.api.nvim_buf_is_valid(new_lyt.commits_bufnr) then
      -- Get cursor position in commits window, or default to line 1
      local lnum = 1 ---@type integer
      if new_lyt.commits_winnr and vim.api.nvim_win_is_valid(new_lyt.commits_winnr) then
        lnum = vim.api.nvim_win_get_cursor(new_lyt.commits_winnr)[1]
      end

      local item = pane_commits.get_item_at_line(new_lyt.commits_bufnr, lnum)

      if item and item.commit then
        -- Resolve against the authoritative state snapshot.
        local commits = ctx.state:get_commits()
        for _, c in ipairs(commits) do
          if c.hash == item.commit.hash then
            current_commit = c
            ctx.state:set_current_commit(current_commit)
            update_lnum_present(ctx, current_commit.hash)
            break
          end
        end
      end
    end

    if current_commit and not current_commit.files then
      -- Load files asynchronously then render filetree
      stl.async.run(function()
        M.__load_commit_files_and_render_filetree__(ctx, current_commit)
      end)
    else
      commits_view.render_filetree(ctx)
    end
  end

  if new_lyt.commits_winnr and vim.api.nvim_win_is_valid(new_lyt.commits_winnr) then
    commits_view.focus_commits(ctx.layout)
  end

  -- Update tabline
  dot.state.status.dirtier_tabline:mark_dirty()
end

----------------------------------------------------------------------------------------------------
-- File operations
----------------------------------------------------------------------------------------------------

---Open file in previous/existing tab (keeps diffview open)
---@param ctx                            era.m.diffview.view.commits.IContext
function M.goto_file(ctx)
  local entry = ctx.state:get_current_entry()
  if not entry then
    return
  end

  local filepath = dot.path.join(dot.path.workspace(), entry.filepath)
  if not vim.uv.fs_stat(filepath) then
    stl.reporter.warn({
      from = __module_name__,
      subject = "goto_file",
      message = "File does not exist: " .. entry.filepath,
    })
    return
  end

  -- Find a non-diffview tab to open the file in
  local target_tabnr = nil ---@type integer|nil
  local current_tabnr = vim.api.nvim_get_current_tabpage()

  for _, tabnr in ipairs(vim.api.nvim_list_tabpages()) do
    if tabnr ~= current_tabnr then
      local tabtype = vim.t[tabnr].tabtype
      if not tabtype or tabtype == stl.e.TabTypeEnum.NORMAL then
        target_tabnr = tabnr
        break
      end
    end
  end

  if target_tabnr then
    -- Switch to existing tab and open file
    vim.api.nvim_set_current_tabpage(target_tabnr)
    vim.cmd.edit(filepath)
  else
    -- No suitable tab exists, create new tab
    vim.cmd("tabnew " .. vim.fn.fnameescape(filepath))
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    vim.t[tabnr].tabtype = stl.e.TabTypeEnum.NORMAL
  end
end

---Open file in new tab (keeps diffview open)
---@param ctx                            era.m.diffview.view.commits.IContext
function M.goto_file_tab(ctx)
  local entry = ctx.state:get_current_entry()
  if not entry then
    return
  end

  local filepath = dot.path.join(dot.path.workspace(), entry.filepath)
  if not vim.uv.fs_stat(filepath) then
    stl.reporter.warn({
      from = __module_name__,
      subject = "goto_file_tab",
      message = "File does not exist: " .. entry.filepath,
    })
    return
  end

  -- Create new tab with file
  vim.cmd("tabnew " .. vim.fn.fnameescape(filepath))
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  vim.t[tabnr].tabtype = stl.e.TabTypeEnum.NORMAL
end

----------------------------------------------------------------------------------------------------
-- Lifecycle actions
----------------------------------------------------------------------------------------------------

---Refresh the view
---@async
---@param ctx                            era.m.diffview.view.commits.IContext
---@param token                          ?stl.c.CancellationToken
function M.refresh(ctx, token)
  local path_filter = ctx.state:get_path_filter()

  -- Fetch total count first
  local total = data.fetch_log_count(path_filter, token)

  if token and token:is_cancelled() then
    return
  end

  stl.async.scheduler()
  ctx.state:set_commits_total(total)

  -- Reset to page 1 on refresh
  ctx.state:set_commits_page(1)
  ctx.state.expanded_commits:next({})

  -- Fetch first page
  local per_page = config.COMMITS_PER_PAGE
  local commits = data.fetch_log_page(1, per_page, path_filter, token)

  if token and token:is_cancelled() then
    return
  end

  stl.async.scheduler()
  ctx.state:set_commits(commits)
  commits_view.render_commits(ctx)

  -- Update tabline
  dot.state.status.dirtier_tabline:mark_dirty()
end

---Close the diffview
---@param ctx                            era.m.diffview.view.commits.IContext
function M.close(ctx)
  commits_state.remove(ctx.layout.tabnr)
  commits_view.remove_layout(ctx.layout.tabnr)
  commits_view.destroy(ctx.layout)
end

----------------------------------------------------------------------------------------------------
-- Help action
----------------------------------------------------------------------------------------------------

---Show keymap help
---@param ctx                            era.m.diffview.view.commits.IContext
function M.show_help(ctx)
  local keymap = require("era.m.diffview.view.commits.keymap")
  local keymaps = keymap.get_help_keymaps(ctx)

  local sheet = era.view.Keysheet.new({
    title = "Diffview Commits Keybindings",
    keymaps = keymaps,
  })
  sheet:open()
end

----------------------------------------------------------------------------------------------------
-- Protected helpers
----------------------------------------------------------------------------------------------------

---Expand commit and load its files
---@async
---@param ctx                            era.m.diffview.view.commits.IContext
---@param commit                         era.m.diffview.ICommit
---@param token                          ?stl.c.CancellationToken
function M.__expand_commit__(ctx, commit, token)
  local actual_commit = find_commit_in_state(ctx, commit.hash)
  if not actual_commit then
    return
  end

  if actual_commit.files then
    stl.async.scheduler()
    ctx.state:toggle_commit_expanded(actual_commit.hash)
    commits_view.render_commits(ctx)
    return
  end

  local files = data.fetch_commit_files(actual_commit.hash, token)
  stl.async.scheduler()
  actual_commit.files = files
  ctx.state:toggle_commit_expanded(actual_commit.hash)
  commits_view.render_commits(ctx)
end

---Load commit files and render filetree (for layout 5)
---@async
---@param ctx                            era.m.diffview.view.commits.IContext
---@param commit                         era.m.diffview.ICommit
---@param token                          ?stl.c.CancellationToken
function M.__load_commit_files_and_render_filetree__(ctx, commit, token)
  local actual_commit = find_commit_in_state(ctx, commit.hash)
  if not actual_commit then
    return
  end

  if actual_commit.files then
    stl.async.scheduler()
    commits_view.render_filetree(ctx)
    return
  end

  local files = data.fetch_commit_files(actual_commit.hash, token)
  if token and token:is_cancelled() then
    return
  end

  stl.async.scheduler()
  actual_commit.files = files
  commits_view.render_filetree(ctx)
end

---Open target file diff directly (for file history mode)
---@param ctx                            era.m.diffview.view.commits.IContext
---@param commit                         era.m.diffview.ICommit
---@param path_filter                    string
function M.__open_target_file_diff__(ctx, commit, path_filter)
  local actual_commit = find_commit_in_state(ctx, commit.hash)
  if not actual_commit then
    return
  end

  ctx.state:set_current_commit(actual_commit)
  update_lnum_present(ctx, actual_commit.hash)
  dot.state.status.dirtier_tabline:mark_dirty()

  stl.async.run(function()
    if not actual_commit.files then
      actual_commit.files = data.fetch_commit_files(actual_commit.hash)
    end
    stl.async.scheduler()

    -- Find target file entry
    local target_entry = nil ---@type era.m.diffview.IFileEntry|nil
    for _, entry in ipairs(actual_commit.files or {}) do
      if entry.filepath == path_filter then
        target_entry = entry
        break
      end
    end

    if not target_entry then
      stl.reporter.warn({
        from = __module_name__,
        subject = "__open_target_file_diff__",
        message = string.format("File not found in commit: %s", path_filter),
      })
      return
    end

    ctx.state:set_current_entry(target_entry)
    commits_view.open_entry(ctx, actual_commit, target_entry)
  end)
end

---Select commit and render filetree (for layout 5)
---@param ctx                            era.m.diffview.view.commits.IContext
---@param commit                         era.m.diffview.ICommit
function M.__select_commit_for_filetree__(ctx, commit)
  local actual_commit = find_commit_in_state(ctx, commit.hash)
  if not actual_commit then
    return
  end

  ctx.state:set_current_commit(actual_commit)
  update_lnum_present(ctx, actual_commit.hash)
  dot.state.status.dirtier_tabline:mark_dirty()

  if not actual_commit.files then
    stl.async.run(function()
      M.__load_commit_files_and_render_filetree__(ctx, actual_commit)
    end)
  else
    commits_view.render_filetree(ctx)
  end
end

---Refresh commits for a specific page
---@async
---@param ctx                            era.m.diffview.view.commits.IContext
---@param page                           integer
---@param token                          ?stl.c.CancellationToken
function M.__refresh_page__(ctx, page, token)
  local path_filter = ctx.state:get_path_filter()
  local per_page = config.COMMITS_PER_PAGE
  local commits = data.fetch_log_page(page, per_page, path_filter, token)

  if token and token:is_cancelled() then
    return
  end

  stl.async.scheduler()
  ctx.state:set_commits(commits)
  commits_view.render_commits(ctx)

  -- Update tabline
  dot.state.status.dirtier_tabline:mark_dirty()
end

---Update cursor in commits pane to match commit hash
---@param ctx                            era.m.diffview.view.commits.IContext
---@param hash                           string
function M.__update_commits_cursor__(ctx, hash)
  local lyt = ctx.layout

  if not lyt.commits_bufnr or not vim.api.nvim_buf_is_valid(lyt.commits_bufnr) then
    return
  end

  local line_map = pane_commits.get_line_map(lyt.commits_bufnr)
  if not line_map then
    return
  end

  local target_lnum = pane_commits.find_commit_line(line_map, hash)
  if target_lnum and lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
    vim.api.nvim_win_set_cursor(lyt.commits_winnr, { target_lnum, 0 })
  end
end

---Show commit details in a floating popup
---@param abbrev_hash                    string
---@param lines                          string[]
function M.__show_commit_popup__(abbrev_hash, lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "git", { buf = bufnr })

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)

  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    title = string.format(" Commit: %s ", abbrev_hash),
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("cursorline", true, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("wrap", true, { win = winnr, scope = "local" })

  -- Close on q or Esc
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end, { buffer = bufnr, nowait = true })
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end, { buffer = bufnr, nowait = true })
end

return M
