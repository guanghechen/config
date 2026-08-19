---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.action" ---@type string

local data = require("era.m.diffview.data")
local pane_changes = require("era.m.diffview.pane.changes")
local pane_sbs = require("era.m.diffview.pane.sbs")
local util = require("era.m.diffview.util")
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
  if workspace_view.is_changes_buffer(ctx.layout, vim.api.nvim_get_current_buf()) then
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
  local visible_entry_ids = {} ---@type table<string, boolean>
  local has_line_map = false
  for _, pane in ipairs(workspace_view.get_changes_panes(ctx.layout)) do
    if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
      local line_map = pane_changes.get_line_map(pane.bufnr)
      if line_map then
        has_line_map = true
        for _, item in ipairs(line_map) do
          local entry = item.entry ---@type era.m.diffview.IFileEntry|nil
          if item.type == "file" and entry then
            visible_entry_ids[get_entry_id(entry)] = true
          end
        end
      end
    end
  end
  if not has_line_map then
    return entries, nil
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
  local move_changes_focus = workspace_view.is_changes_buffer(ctx.layout, vim.api.nvim_get_current_buf())
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
  if move_changes_focus and target_entry.stage_type then
    workspace_view.focus_changes(ctx.layout, target_entry.stage_type)
  end

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
  ctx.state:toggle_collapse(assert(item.stage_type), item.uuid)

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

---Move to the visible parent in the active Changes tree.
function M.goto_parent_node()
  pane_changes.goto_parent_node()
end

---Move to the last child or sibling in the active Changes tree.
function M.goto_last_child_or_sibling()
  pane_changes.goto_last_child_or_sibling()
end

----------------------------------------------------------------------------------------------------
-- Git operations
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.workspace.ITransferContext
---@field public entry_ids              table<string, true>
---@field public fallback               era.m.diffview.IFileEntry|nil
---@field public source_stage_type      stl.m.diffview.StageTypeEnum
---@field public destination_stage_type stl.m.diffview.StageTypeEnum

---@class era.m.diffview.view.workspace.ITransferTarget
---@field public entries                era.m.diffview.IFileEntry[]
---@field public filepath               string
---@field public anchor_lnum            integer|nil

---@param filepath                      string
---@param directory                     string
---@return boolean
local function is_directory_descendant(filepath, directory)
  local prefix = directory:sub(-1) == "/" and directory or (directory .. "/") ---@type string
  return filepath:sub(1, #prefix) == prefix
end

---Resolve a file or directory transfer target from the active workspace pane.
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param source_stage_type              stl.m.diffview.StageTypeEnum
---@return era.m.diffview.view.workspace.ITransferTarget|nil
local function get_transfer_target(ctx, source_stage_type)
  local entry = get_action_entry(ctx)
  if entry then
    if entry.stage_type ~= source_stage_type then
      return nil
    end
    return {
      entries = { entry },
      filepath = entry.filepath,
      anchor_lnum = nil,
    }
  end

  if not workspace_view.is_changes_buffer(ctx.layout, vim.api.nvim_get_current_buf()) then
    return nil
  end

  local bufnr, lnum = get_cursor_info()
  local item = pane_changes.get_item_at_line(bufnr, lnum)
  if not item or item.type ~= "directory" or item.stage_type ~= source_stage_type or not item.uuid then
    return nil
  end

  local entries = {} ---@type era.m.diffview.IFileEntry[]
  for _, candidate in ipairs(ctx.state:get_entries()) do
    if candidate.stage_type == source_stage_type and is_directory_descendant(candidate.filepath, item.uuid) then
      entries[#entries + 1] = candidate
    end
  end
  if #entries == 0 then
    return nil
  end

  return {
    entries = entries,
    filepath = item.uuid,
    anchor_lnum = lnum,
  }
end

---Build exact NUL-delimited pathspec input without placing repository paths in argv.
---@param target                         era.m.diffview.view.workspace.ITransferTarget
---@return string
local function build_transfer_pathspec_input(target)
  local paths = {} ---@type string[]
  local seen = {} ---@type table<string, boolean>

  ---@param filepath                    string|nil
  local function append(filepath)
    if filepath and not seen[filepath] then
      seen[filepath] = true
      paths[#paths + 1] = filepath
    end
  end

  for _, entry in ipairs(target.entries) do
    if entry.status == "R" then
      append(entry.prev_filepath)
    end
    append(entry.filepath)
  end

  return table.concat(paths, "\0") .. "\0"
end

---Capture the next visible item in the source work queue before Git moves the target.
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param target                         era.m.diffview.view.workspace.ITransferTarget
---@param destination_stage_type         stl.m.diffview.StageTypeEnum
---@return era.m.diffview.view.workspace.ITransferContext
local function capture_transfer(ctx, target, destination_stage_type)
  local source_stage_type = assert(target.entries[1].stage_type) ---@type stl.m.diffview.StageTypeEnum
  local entry_ids = {} ---@type table<string, true>
  for _, entry in ipairs(target.entries) do
    entry_ids[get_entry_id(entry)] = true
  end

  local pane = workspace_view.get_changes_pane(ctx.layout, source_stage_type)
  local fallback = nil ---@type era.m.diffview.IFileEntry|nil
  if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
    local line_map = pane_changes.get_line_map(pane.bufnr)
    if line_map then
      local anchor_lnum = target.anchor_lnum
      if anchor_lnum == nil and #target.entries == 1 then
        anchor_lnum = pane_changes.find_entry_line(line_map, target.entries[1])
      end
      if anchor_lnum then
        for i = anchor_lnum + 1, #line_map do
          local candidate = line_map[i].entry ---@type era.m.diffview.IFileEntry|nil
          if line_map[i].type == "file" and candidate and not entry_ids[get_entry_id(candidate)] then
            fallback = candidate
            break
          end
        end
        if not fallback then
          for i = anchor_lnum - 1, 1, -1 do
            local candidate = line_map[i].entry ---@type era.m.diffview.IFileEntry|nil
            if line_map[i].type == "file" and candidate and not entry_ids[get_entry_id(candidate)] then
              fallback = candidate
              break
            end
          end
        end
      end
    end
  end

  return {
    entry_ids = entry_ids,
    fallback = fallback,
    source_stage_type = source_stage_type,
    destination_stage_type = destination_stage_type,
  }
end

---Refresh after a stage transfer without stealing a newer selection or focus.
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param transfer                       era.m.diffview.view.workspace.ITransferContext
local function refresh_after_transfer(ctx, transfer)
  if ctx.state.is_disposed and ctx.state:is_disposed() then
    return
  end
  local current = ctx.state:get_current_entry()
  if current and transfer.entry_ids[get_entry_id(current)] and transfer.fallback then
    ctx.state:set_current_entry(transfer.fallback)
  end

  ctx.state:request_refresh(function()
    if ctx.state.is_disposed and ctx.state:is_disposed() then
      return
    end
    local source = workspace_view.get_changes_pane(ctx.layout, transfer.source_stage_type)
    local source_has_visible_entries = false
    if source.bufnr and vim.api.nvim_buf_is_valid(source.bufnr) then
      local line_map = pane_changes.get_line_map(source.bufnr)
      if line_map then
        for _, item in ipairs(line_map) do
          if item.type == "file" and item.entry then
            source_has_visible_entries = true
            break
          end
        end
      end
    end
    if
      not source_has_visible_entries
      and source.winnr
      and vim.api.nvim_win_is_valid(source.winnr)
      and vim.api.nvim_get_current_win() == source.winnr
    then
      workspace_view.focus_changes(ctx.layout, transfer.destination_stage_type)
    end
  end)
end

---Stage the file or directory targeted by the active workspace pane
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.stage(ctx)
  local target = get_transfer_target(ctx, "unstaged")
  if not target then
    return
  end

  local args = {
    "--literal-pathspecs",
    "add",
    "--pathspec-from-file=-",
    "--pathspec-file-nul",
  } ---@type string[]
  local pathspec_input = build_transfer_pathspec_input(target)
  local transfer = capture_transfer(ctx, target, "staged")

  stl.git.exec.exec_async(args, { cwd = dot.path.workspace(), stdin = pathspec_input }, function(_, code, stderr)
    if code ~= 0 then
      report_git_failure("stage", target.filepath, code, stderr)
      return
    end

    refresh_after_transfer(ctx, transfer)
  end)
end

---Unstage the file or directory targeted by the active workspace pane
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.unstage(ctx)
  local target = get_transfer_target(ctx, "staged")
  if not target then
    return
  end
  local transfer = capture_transfer(ctx, target, "unstaged")

  local workspace = dot.path.workspace()
  local function on_unstage(_, code, stderr)
    if code ~= 0 then
      report_git_failure("unstage", target.filepath, code, stderr)
      return
    end

    refresh_after_transfer(ctx, transfer)
  end

  stl.git.exec.exec_async(
    { "rev-parse", "--verify", "--quiet", "HEAD^{commit}" },
    { cwd = workspace },
    function(_, code, stderr)
      if code == 1 then
        local args = {
          "--literal-pathspecs",
          "rm",
          "--cached",
          "-f",
          "--pathspec-from-file=-",
          "--pathspec-file-nul",
        } ---@type string[]
        stl.git.exec.exec_async(args, { cwd = workspace, stdin = build_transfer_pathspec_input(target) }, on_unstage)
        return
      end
      if code ~= 0 then
        report_git_failure("unstage", target.filepath, code, stderr)
        return
      end

      local args = {
        "--literal-pathspecs",
        "reset",
        "HEAD",
        "--pathspec-from-file=-",
        "--pathspec-file-nul",
      } ---@type string[]
      stl.git.exec.exec_async(args, { cwd = workspace, stdin = build_transfer_pathspec_input(target) }, on_unstage)
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
    ctx.state:request_refresh()
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
    local absolute = util.workspace_path(entry.filepath)
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

    ctx.state:request_refresh()
    return
  end

  -- Tracked files: git checkout
  stl.git.exec.exec_async(
    { "--literal-pathspecs", "checkout", "--", entry.filepath },
    { cwd = dot.path.workspace() },
    function(_, code, stderr)
      if code ~= 0 then
        report_git_failure("discard", entry.filepath, code, stderr)
        return
      end

      ctx.state:request_refresh()
    end
  )
end

----------------------------------------------------------------------------------------------------
-- File operations
----------------------------------------------------------------------------------------------------

---Copy the file entry at cursor in the changes pane
---@return nil
function M.copy_filepath()
  local entry = get_entry_at_cursor()
  if not entry then
    return
  end

  era.fn.select_copy_filepath({
    filepath = util.workspace_path(entry.filepath),
    relative = "cursor",
    row = 1,
    col = 4,
  })
end

---Open file in previous/existing tab (keeps diffview open)
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.goto_file(ctx)
  local entry = ctx.state:get_current_entry()
  if not entry then
    return
  end

  local filepath = util.workspace_path(entry.filepath)
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
    vim.cmd.edit(vim.fn.fnameescape(filepath))
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

  local filepath = util.workspace_path(entry.filepath)
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
  local current = ctx.state:get_current_entry()
  local dir = get_current_entry_dir(ctx)
  if not current or not current.stage_type or not dir or dir == "." then
    return
  end

  ctx.state:toggle_collapse(current.stage_type, dir)
  workspace_view.render_changes(ctx)
end

---Expand directory from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_expand(ctx)
  local current = ctx.state:get_current_entry()
  local dir = get_current_entry_dir(ctx)
  if not current or not current.stage_type or not dir or dir == "." then
    return
  end

  if ctx.state:is_collapsed(current.stage_type, dir) then
    ctx.state:expand_dir(current.stage_type, dir)
    workspace_view.render_changes(ctx)
  end
end

---Collapse directory from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_collapse(ctx)
  local current = ctx.state:get_current_entry()
  local dir = get_current_entry_dir(ctx)
  if not current or not current.stage_type or not dir or dir == "." then
    return
  end

  if not ctx.state:is_collapsed(current.stage_type, dir) then
    ctx.state:collapse_dir(current.stage_type, dir)
    workspace_view.render_changes(ctx)
  end
end

---Expand all directories from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_expand_all(ctx)
  local current = ctx.state:get_current_entry()
  if not current or not current.stage_type then
    return
  end
  ctx.state:expand_all(current.stage_type)
  workspace_view.render_changes(ctx)
end

---Collapse all directories from sbs window
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.sbs_collapse_all(ctx)
  local current = ctx.state:get_current_entry()
  if not current or not current.stage_type then
    return
  end
  ctx.state:collapse_all(current.stage_type)
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
  -- Let in-flight Git reads settle; the token guards view ownership and prevents writes after disposal.
  local entries = data.fetch_diff_entries()

  if token and token:is_cancelled() then
    return
  end

  stl.async.scheduler()
  if token and token:is_cancelled() then
    return
  end

  local current = ctx.state:get_current_entry()
  if ctx.state:is_entries_snapshot_applied() and data.equal_diff_entries(ctx.state:get_entries(), entries) then
    -- Panel metadata can stay unchanged while the selected Git blob changes.
    -- Keep the canonical panel snapshot, but refresh its preview content.
    workspace_view.sync_changes_heights(ctx)
    if current then
      workspace_view.open_entry(ctx, current, token, { preserve_view = true })
    end
    return
  end

  local previous_entries = {} ---@type era.m.diffview.IFileEntry[]
  if current then
    previous_entries = get_navigation_entries(ctx)
  end

  ctx.state:set_entries(entries)
  workspace_view.render_changes(ctx)

  if current then
    local refreshed_entries, visible_entry_ids = get_navigation_entries(ctx)
    local refreshed_entry = resolve_refreshed_entry(current, previous_entries, refreshed_entries, visible_entry_ids)

    if refreshed_entry then
      M.__update_changes_cursor__(ctx, refreshed_entry)
      workspace_view.open_entry(ctx, refreshed_entry, token, {
        preserve_view = get_entry_id(current) == get_entry_id(refreshed_entry),
      })
    else
      workspace_view.clear_sbs(ctx)
    end
    ctx.state:set_current_entry(refreshed_entry)
  end

  -- Update tabline
  dot.state.status.dirtier_tabline:mark_dirty()
  ctx.state:commit_entries_snapshot()
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
  if not entry.stage_type then
    return
  end
  local pane = workspace_view.get_changes_pane(lyt, entry.stage_type)
  if not pane.bufnr or not vim.api.nvim_buf_is_valid(pane.bufnr) then
    return
  end
  local line_map = pane_changes.get_line_map(pane.bufnr)
  if not line_map then
    return
  end

  local target_lnum = pane_changes.find_entry_line(line_map, entry)
  if target_lnum and pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
    vim.api.nvim_win_set_cursor(pane.winnr, { target_lnum, 0 })
  end
end

return M
