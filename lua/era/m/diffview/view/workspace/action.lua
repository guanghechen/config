---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.action" ---@type string

local data = require("era.m.diffview.data")
local pane_changes = require("era.m.diffview.pane.changes")
local pane_sbs = require("era.m.diffview.pane.sbs")
local workspace_state = require("era.m.diffview.view.workspace.state")
local workspace_view = require("era.m.diffview.view.workspace.view")

---Workspace view actions.
---@class era.m.diffview.view.workspace.action
local M = {}

----------------------------------------------------------------------------------------------------
-- Type definitions
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.workspace.IContext
---@field public layout                  era.m.diffview.view.workspace.ILayout
---@field public state                   era.m.diffview.view.workspace.State

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

---Get file entry at cursor in changes pane
---@return era.m.diffview.IFileEntry|nil
local function get_entry_at_cursor()
  local bufnr, lnum = get_cursor_info()
  return pane_changes.get_entry_at_line(bufnr, lnum)
end

---Get the entry targeted by an action from the active workspace pane.
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return era.m.diffview.IFileEntry|nil
local function get_action_entry(ctx)
  if vim.api.nvim_get_current_buf() == ctx.layout.changes_bufnr then
    return get_entry_at_cursor()
  end
  return ctx.state:get_current_entry()
end

---@param operation                     string
---@param filepath                      string
---@param code                          integer
---@param stderr                        string
local function report_git_failure(operation, filepath, code, stderr)
  local reason = vim.trim(stderr)
  local message = string.format("Failed to %s `%s` (exit %d)", operation, filepath, code)
  message = reason == "" and (message .. ".") or (message .. ": " .. reason)

  stl.reporter.error({
    from = __module_name__,
    subject = operation,
    message = message,
  })
end

---@param entry                          era.m.diffview.IFileEntry
---@return string
local function get_entry_id(entry)
  return (entry.stage_type or "") .. "\0" .. entry.filepath
end

---Get entries in panel order and the subset currently visible in the changes pane.
---Falls back to state order with every entry visible when the workspace has no changes pane.
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return era.m.diffview.IFileEntry[] entries
---@return table<string, boolean>|nil visible_entry_ids
local function get_navigation_entries(ctx)
  local entries = ctx.state:get_entries()
  local changes_bufnr = ctx.layout.changes_bufnr
  if not changes_bufnr or not vim.api.nvim_buf_is_valid(changes_bufnr) then
    return entries, nil
  end

  local line_map = pane_changes.get_line_map(changes_bufnr)
  if not line_map then
    return entries, nil
  end

  local visible_entry_ids = {} ---@type table<string, boolean>
  for _, item in ipairs(line_map) do
    local entry = item.entry ---@type era.m.diffview.IFileEntry|nil
    if item.type == "file" and entry then
      visible_entry_ids[get_entry_id(entry)] = true
    end
  end
  return pane_changes.get_entries_in_render_order(entries), visible_entry_ids
end

---Resolve current selection against freshly rendered entries.
---@param current                        era.m.diffview.IFileEntry
---@param previous_entries               era.m.diffview.IFileEntry[]
---@param entries                        era.m.diffview.IFileEntry[]
---@param visible_entry_ids              table<string, boolean>|nil
---@return era.m.diffview.IFileEntry|nil
local function resolve_refreshed_entry(current, previous_entries, entries, visible_entry_ids)
  local current_id = get_entry_id(current)
  local entries_by_id = {} ---@type table<string, era.m.diffview.IFileEntry>

  for _, entry in ipairs(entries) do
    local entry_id = get_entry_id(entry)
    entries_by_id[entry_id] = entry
    if entry_id == current_id then
      return entry
    end
  end

  for _, entry in ipairs(entries) do
    if entry.filepath == current.filepath then
      return entry
    end
  end

  local function get_visible_entry(entry)
    local refreshed = entries_by_id[get_entry_id(entry)]
    if refreshed and (not visible_entry_ids or visible_entry_ids[get_entry_id(refreshed)]) then
      return refreshed
    end
  end

  local current_idx = nil ---@type integer|nil
  for i, entry in ipairs(previous_entries) do
    if get_entry_id(entry) == current_id then
      current_idx = i
      break
    end
  end

  if current_idx then
    for i = current_idx + 1, #previous_entries do
      local entry = get_visible_entry(previous_entries[i])
      if entry then
        return entry
      end
    end
    for i = current_idx - 1, 1, -1 do
      local entry = get_visible_entry(previous_entries[i])
      if entry then
        return entry
      end
    end
  end

  for _, entry in ipairs(entries) do
    if not visible_entry_ids or visible_entry_ids[get_entry_id(entry)] then
      return entry
    end
  end
end

---Navigate to an adjacent entry and keep state, panel cursor, and preview in sync.
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param direction                      1|-1
local function goto_adjacent_entry(ctx, direction)
  local entries, visible_entry_ids = get_navigation_entries(ctx)
  if #entries == 0 then
    return
  end

  local current = ctx.state:get_current_entry()
  local current_idx = nil ---@type integer|nil
  if current then
    for i, entry in ipairs(entries) do
      if entry.filepath == current.filepath and entry.stage_type == current.stage_type then
        current_idx = i
        break
      end
    end
  end

  local start_idx = current_idx or (direction == 1 and 0 or 1)
  local target_entry = nil ---@type era.m.diffview.IFileEntry|nil
  for offset = 1, #entries do
    local target_idx = ((start_idx - 1 + direction * offset) % #entries) + 1
    local entry = entries[target_idx]
    if not visible_entry_ids or visible_entry_ids[get_entry_id(entry)] then
      target_entry = entry
      break
    end
  end

  if not target_entry then
    return
  end

  ctx.state:set_current_entry(target_entry)
  M.__update_changes_cursor__(ctx, target_entry)

  stl.async.run(function()
    workspace_view.open_entry(ctx, target_entry)
  end)
end

----------------------------------------------------------------------------------------------------
-- Selection actions
----------------------------------------------------------------------------------------------------

---Select entry at cursor in changes panel
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.select(ctx)
  local bufnr, lnum = get_cursor_info()

  -- Check if it's a directory
  if pane_changes.is_directory(bufnr, lnum) then
    M.toggle_collapse(ctx)
    return
  end

  local entry = pane_changes.get_entry_at_line(bufnr, lnum)
  if not entry then
    return
  end

  ctx.state:set_current_entry(entry)

  -- Open in side-by-side view
  stl.async.run(function()
    workspace_view.open_entry(ctx, entry)
  end)
end

---Toggle directory collapse at cursor
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.toggle_collapse(ctx)
  local winnr = vim.api.nvim_get_current_win()
  local bufnr, lnum = get_cursor_info()

  -- Get item at line
  local item = pane_changes.get_item_at_line(bufnr, lnum)
  if not item or item.type ~= "directory" or not item.uuid then
    return
  end

  -- Toggle in state
  ctx.state:toggle_collapse(item.uuid)

  -- Re-render
  workspace_view.render_changes(ctx)

  -- Restore cursor position
  vim.api.nvim_win_set_cursor(winnr, { lnum, 0 })
end

----------------------------------------------------------------------------------------------------
-- Navigation actions
----------------------------------------------------------------------------------------------------

---Move to next file entry in changes pane (skips directories)
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.next_entry(ctx)
  local bufnr, lnum = get_cursor_info()
  local winnr = vim.api.nvim_get_current_win()
  local line_map = pane_changes.get_line_map(bufnr)

  if not line_map then
    return
  end

  -- Find next file entry (with actual entry, not directory)
  for i = lnum + 1, #line_map do
    local item = line_map[i]
    if item.type == "file" and item.entry ~= nil then
      vim.api.nvim_win_set_cursor(winnr, { i, 0 })
      M.select(ctx)
      return
    end
  end
end

---Move to previous file entry in changes pane (skips directories)
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.prev_entry(ctx)
  local bufnr, lnum = get_cursor_info()
  local winnr = vim.api.nvim_get_current_win()
  local line_map = pane_changes.get_line_map(bufnr)

  if not line_map then
    return
  end

  -- Find previous file entry (with actual entry, not directory)
  for i = lnum - 1, 1, -1 do
    local item = line_map[i]
    if item.type == "file" and item.entry ~= nil then
      vim.api.nvim_win_set_cursor(winnr, { i, 0 })
      M.select(ctx)
      return
    end
  end
end

---Navigate to next file entry (from any window)
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.goto_next_entry(ctx)
  goto_adjacent_entry(ctx, 1)
end

---Navigate to previous file entry (from any window)
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.goto_prev_entry(ctx)
  goto_adjacent_entry(ctx, -1)
end

----------------------------------------------------------------------------------------------------
-- Git operations
----------------------------------------------------------------------------------------------------

---Stage the file targeted by the active workspace pane
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.stage(ctx)
  local entry = get_action_entry(ctx)
  if not entry or entry.stage_type ~= "unstaged" then
    return
  end

  stl.git.exec.exec_async({ "add", "--", entry.filepath }, { cwd = dot.path.workspace() }, function(_, code, stderr)
    if code ~= 0 then
      report_git_failure("stage", entry.filepath, code, stderr)
      return
    end

    stl.async.run(function()
      M.refresh(ctx)
    end)
  end)
end

---Unstage the file targeted by the active workspace pane
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.unstage(ctx)
  local entry = get_action_entry(ctx)
  if not entry or entry.stage_type ~= "staged" then
    return
  end

  stl.git.exec.exec_async(
    { "reset", "HEAD", "--", entry.filepath },
    { cwd = dot.path.workspace() },
    function(_, code, stderr)
      if code ~= 0 then
        report_git_failure("unstage", entry.filepath, code, stderr)
        return
      end

      stl.async.run(function()
        M.refresh(ctx)
      end)
    end
  )
end

---@param ctx                            era.m.diffview.view.workspace.IContext
---@param range                          ?{ [1]: integer, [2]: integer }
---@return stl.c.Future|nil
function M.unstage_hunk(ctx, range)
  local entry = ctx.state:get_current_entry() ---@type era.m.diffview.IFileEntry|nil
  if not entry or entry.stage_type ~= "staged" then
    stl.reporter.warn({
      from = __module_name__,
      subject = "unstage_hunk",
      message = "Select a staged entry before unstaging a hunk.",
    })
    return
  end

  local right_winnr = ctx.layout.sbs_right_winnr ---@type integer|nil
  if not right_winnr or not vim.api.nvim_win_is_valid(right_winnr) then
    stl.reporter.warn({ from = __module_name__, subject = "unstage_hunk", message = "The staged diff is not open." })
    return
  end
  if vim.api.nvim_get_current_win() ~= right_winnr then
    stl.reporter.warn({
      from = __module_name__,
      subject = "unstage_hunk",
      message = "Move to the index-side window before unstaging a hunk.",
    })
    return
  end
  if entry.status == "R" or entry.status == "C" or entry.status == "D" then
    stl.reporter.warn({
      from = __module_name__,
      subject = "unstage_hunk",
      message = "This entry can only be unstaged as a whole; use `gu` in the file list.",
    })
    return
  end

  local right_bufnr = vim.api.nvim_win_get_buf(right_winnr) ---@type integer
  local expected_name = era.m.diffview.util.gen_index_bufname(entry.filepath) ---@type string
  if vim.api.nvim_buf_get_name(right_bufnr) ~= expected_name then
    stl.reporter.warn({
      from = __module_name__,
      subject = "unstage_hunk",
      message = "The staged diff is still loading; try again.",
    })
    return
  end

  if not range then
    local lnum = vim.api.nvim_win_get_cursor(right_winnr)[1] ---@type integer
    range = { lnum, lnum }
  end
  local index_document = era.m.git.staging.from_buffer(right_bufnr) ---@type era.m.git.Document
  local object_name = vim.b[right_bufnr].git_object_name ---@type string|nil
  if not object_name then
    stl.reporter.warn({
      from = __module_name__,
      subject = "unstage_hunk",
      message = "The staged diff has no authoritative index snapshot; reopen it and try again.",
    })
    return
  end

  local future = era.m.git.buffer.unstage_range({
    expected_index = { document = index_document, object_name = object_name },
    range = range,
    relpath = entry.filepath,
    toplevel = dot.path.workspace(),
  })
  future:finally(function(resolved, result)
    if not resolved or type(result) ~= "table" or not result.ok then
      local reason = type(result) == "table" and result.err or result ---@type string|nil
      stl.reporter.warn({ from = __module_name__, subject = "unstage_hunk", message = reason or "Failed to unstage" })
      return
    end
    stl.async.run(function()
      M.refresh(ctx)
    end)
  end)
  return future
end

---Toggle stage/unstage for file at cursor
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.toggle_stage(ctx)
  local entry = get_entry_at_cursor()
  if not entry then
    return
  end

  if entry.stage_type == "staged" then
    M.unstage(ctx)
  else
    M.stage(ctx)
  end
end

---Reset (discard) file at cursor
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.reset(ctx)
  local entry = get_entry_at_cursor()
  if not entry or entry.stage_type ~= "unstaged" then
    return
  end

  -- Untracked files: remove them
  if entry.status == "?" then
    local absolute = dot.path.join(dot.path.workspace(), entry.filepath)
    local ok, err = stl.os.fs.delete(absolute)
    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "discard",
        message = string.format("Failed to discard `%s`: unable to delete the untracked file.", entry.filepath),
        details = { error = err or "delete_failed" },
      })
      return
    end

    stl.async.run(function()
      M.refresh(ctx)
    end)
    return
  end

  -- Tracked files: git checkout
  stl.git.exec.exec_async(
    { "checkout", "--", entry.filepath },
    { cwd = dot.path.workspace() },
    function(_, code, stderr)
      if code ~= 0 then
        report_git_failure("discard", entry.filepath, code, stderr)
        return
      end

      stl.async.run(function()
        M.refresh(ctx)
      end)
    end
  )
end

----------------------------------------------------------------------------------------------------
-- File operations
----------------------------------------------------------------------------------------------------

---Open file in previous/existing tab (keeps diffview open)
---@param ctx                            era.m.diffview.view.workspace.IContext
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
---@param ctx                            era.m.diffview.view.workspace.IContext
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
-- Focus actions
----------------------------------------------------------------------------------------------------

---Focus changes panel
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.focus_changes(ctx)
  workspace_view.focus_changes(ctx.layout)
end

---Focus left sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.focus_left(ctx)
  workspace_view.focus_left(ctx.layout)
end

---Focus right sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.focus_right(ctx)
  workspace_view.focus_right(ctx.layout)
end

---Cycle focus between panels
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.cycle_focus(ctx)
  workspace_view.cycle_focus(ctx.layout)
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
---@param _                             era.m.diffview.view.workspace.IContext
function M.toggle_fold(_)
  execute_fold("toggle")
end

---Open fold at cursor
---@param _                             era.m.diffview.view.workspace.IContext
function M.open_fold(_)
  execute_fold("open")
end

---Close fold at cursor
---@param _                             era.m.diffview.view.workspace.IContext
function M.close_fold(_)
  execute_fold("close")
end

---Open all folds
---@param _                             era.m.diffview.view.workspace.IContext
function M.open_all_folds(_)
  execute_fold("open_all")
end

---Close all folds
---@param _                             era.m.diffview.view.workspace.IContext
function M.close_all_folds(_)
  execute_fold("close_all")
end

----------------------------------------------------------------------------------------------------
-- SBS panel collapse/expand actions
----------------------------------------------------------------------------------------------------

---Get directory path containing current entry
---@param ctx                            era.m.diffview.view.workspace.IContext
---@return string|nil
local function get_current_entry_dir(ctx)
  local current = ctx.state:get_current_entry()
  if not current then
    return nil
  end
  return vim.fn.fnamemodify(current.filepath, ":h")
end

---Toggle directory collapse from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_toggle_collapse(ctx)
  local dir = get_current_entry_dir(ctx)
  if not dir or dir == "." then
    return
  end

  ctx.state:toggle_collapse(dir)
  workspace_view.render_changes(ctx)
end

---Expand directory from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_expand(ctx)
  local dir = get_current_entry_dir(ctx)
  if not dir or dir == "." then
    return
  end

  if ctx.state:is_collapsed(dir) then
    ctx.state:expand_dir(dir)
    workspace_view.render_changes(ctx)
  end
end

---Collapse directory from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_collapse(ctx)
  local dir = get_current_entry_dir(ctx)
  if not dir or dir == "." then
    return
  end

  if not ctx.state:is_collapsed(dir) then
    ctx.state:collapse_dir(dir)
    workspace_view.render_changes(ctx)
  end
end

---Expand all directories from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_expand_all(ctx)
  ctx.state:expand_all()
  workspace_view.render_changes(ctx)
end

---Collapse all directories from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_collapse_all(ctx)
  ctx.state:collapse_all()
  workspace_view.render_changes(ctx)
end

----------------------------------------------------------------------------------------------------
-- Flag toggles
----------------------------------------------------------------------------------------------------

---Toggle viewtype (tree/list) for changes pane
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.toggle_viewtype(ctx)
  local current = dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
  local next_viewtype = current == "tree" and "list" or "tree" ---@type stl.m.diffview.PanelViewTypeEnum
  dot.context.diffview.flag_panel_viewtype:next(next_viewtype)
  workspace_view.render_changes(ctx)
end

---Toggle fold empty directories
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.toggle_foldempty(ctx)
  local current = dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
  dot.context.diffview.flag_foldempty:next(not current)
  workspace_view.render_changes(ctx)
end

---Toggle folding unchanged hunks in sbs
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.toggle_fold_unchanged(ctx)
  local current = dot.context.diffview.flag_fold_unchanges:snapshot() ---@type boolean
  dot.context.diffview.flag_fold_unchanges:next(not current)

  local lyt = ctx.layout
  pane_sbs.apply_fold_unchanged_pair(lyt.sbs_left_winnr, lyt.sbs_right_winnr)
end

----------------------------------------------------------------------------------------------------
-- Lifecycle actions
----------------------------------------------------------------------------------------------------

---Refresh the view
---@async
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param token                          ?stl.c.CancellationToken
function M.refresh(ctx, token)
  local entries = data.fetch_diff_entries(token)

  if token and token:is_cancelled() then
    return
  end

  stl.async.scheduler()
  if token and token:is_cancelled() then
    return
  end

  local current = ctx.state:get_current_entry()
  local previous_entries = {} ---@type era.m.diffview.IFileEntry[]
  if current then
    previous_entries = get_navigation_entries(ctx)
  end

  ctx.state:set_entries(entries)
  workspace_view.render_changes(ctx)

  if current then
    local refreshed_entries, visible_entry_ids = get_navigation_entries(ctx)
    local refreshed_entry = resolve_refreshed_entry(current, previous_entries, refreshed_entries, visible_entry_ids)
    ctx.state:set_current_entry(refreshed_entry)

    if refreshed_entry then
      M.__update_changes_cursor__(ctx, refreshed_entry)
      workspace_view.open_entry(ctx, refreshed_entry, token, {
        preserve_view = get_entry_id(current) == get_entry_id(refreshed_entry),
      })
    else
      workspace_view.clear_sbs(ctx)
    end
  end

  -- Update tabline
  dot.state.status.dirtier_tabline:mark_dirty()
end

---Close the diffview
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.close(ctx)
  workspace_state.remove(ctx.layout.tabnr)
  workspace_view.remove_layout(ctx.layout.tabnr)
  workspace_view.destroy(ctx.layout)
end

----------------------------------------------------------------------------------------------------
-- Help action
----------------------------------------------------------------------------------------------------

---Show keymap help
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.show_help(ctx)
  local keymap = require("era.m.diffview.view.workspace.keymap")
  local keymaps = keymap.get_help_keymaps(ctx)

  local sheet = era.view.Keysheet.new({
    title = "Diffview Workspace Keybindings",
    keymaps = keymaps,
  })
  sheet:open()
end

----------------------------------------------------------------------------------------------------
-- Protected helpers
----------------------------------------------------------------------------------------------------

---Update cursor in changes pane to match entry
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param entry                          era.m.diffview.IFileEntry
function M.__update_changes_cursor__(ctx, entry)
  local lyt = ctx.layout

  if not lyt.changes_bufnr or not vim.api.nvim_buf_is_valid(lyt.changes_bufnr) then
    return
  end

  local line_map = pane_changes.get_line_map(lyt.changes_bufnr)
  if not line_map then
    return
  end

  local target_lnum = pane_changes.find_entry_line(line_map, entry)
  if target_lnum and lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
    vim.api.nvim_win_set_cursor(lyt.changes_winnr, { target_lnum, 0 })
  end
end

return M
