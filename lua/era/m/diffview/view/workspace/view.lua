---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.view" ---@type string

local config = require("era.m.diffview.config")
local layout_util = require("era.m.diffview.layout")
local pane_changes = require("era.m.diffview.pane.changes")
local pane_sbs = require("era.m.diffview.pane.sbs")

---Workspace view controller.
---Manages layout, pane composition, and lifecycle for Git Diff (staged/unstaged) view.
---@class era.m.diffview.view.workspace.view
local M = {}

----------------------------------------------------------------------------------------------------
-- Type definitions
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.workspace.IChangesPane
---@field public stage_type              stl.m.diffview.StageTypeEnum
---@field public winnr                   integer|nil
---@field public bufnr                   integer|nil

---@class era.m.diffview.view.workspace.IChangesLayout
---@field public staged                  era.m.diffview.view.workspace.IChangesPane
---@field public unstaged                era.m.diffview.view.workspace.IChangesPane
---@field public expanded_staged_height  integer|nil                    Restored after an empty pane expands again
---@field public both_nonempty           boolean                        Last rendered occupancy state

---@class era.m.diffview.view.workspace.ILayout
---@field public tabnr                   integer
---@field public layout_type             integer                         1=changes+sbs, 2=changes only, 3=sbs only
---@field public changes                 era.m.diffview.view.workspace.IChangesLayout
---@field public sbs_left_winnr          integer|nil
---@field public sbs_right_winnr         integer|nil
---@field public preview_generation      integer

---@class era.m.diffview.view.workspace.IOpenEntryOpts
---@field public preserve_view           boolean|nil

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return integer
local function next_preview_generation(lyt)
  lyt.preview_generation = (lyt.preview_generation or 0) + 1
  return lyt.preview_generation
end

---@return era.m.diffview.view.workspace.IChangesLayout
local function create_empty_changes_layout()
  return {
    staged = { stage_type = "staged", winnr = nil, bufnr = nil },
    unstaged = { stage_type = "unstaged", winnr = nil, bufnr = nil },
    expanded_staged_height = nil,
    both_nonempty = false,
  }
end

---Create the vertically stacked Staged and Unstaged sibling panes in one Changes column.
---@param anchor_winnr                  integer
---@return era.m.diffview.view.workspace.IChangesLayout
local function create_changes_layout(anchor_winnr)
  local result = layout_util.create(layout_util.vertical("staged", "unstaged", 0.5), anchor_winnr)
  local changes = create_empty_changes_layout()

  for _, stage_type in ipairs({ "staged", "unstaged" }) do
    local pane = changes[stage_type] ---@type era.m.diffview.view.workspace.IChangesPane
    pane.winnr = result.winnrs[stage_type]
    pane.bufnr = pane_changes.create_buffer(stage_type)
    if pane.winnr then
      vim.api.nvim_win_set_buf(pane.winnr, pane.bufnr)
      pane_changes.apply_winopts(pane.winnr)
    end
  end

  if changes.staged.winnr then
    changes.expanded_staged_height = vim.api.nvim_win_get_height(changes.staged.winnr)
  end
  return changes
end

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@return era.m.diffview.view.workspace.IChangesPane
function M.get_changes_pane(lyt, stage_type)
  return lyt.changes[stage_type]
end

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.IChangesPane[]
function M.get_changes_panes(lyt)
  return { lyt.changes.staged, lyt.changes.unstaged }
end

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param bufnr                          integer
---@return boolean
function M.is_changes_buffer(lyt, bufnr)
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    if pane.bufnr == bufnr then
      return true
    end
  end
  return false
end

----------------------------------------------------------------------------------------------------
-- Layout creation
----------------------------------------------------------------------------------------------------

---Create workspace layout in new tab
---@param layout_type                    integer|nil                     1=changes+sbs (default), 2=changes only, 3=sbs only
---@return era.m.diffview.view.workspace.ILayout
function M.create_layout(layout_type)
  layout_type = layout_type or 1

  -- Create new tab at the end
  vim.cmd("$tabnew")
  local tabnr = vim.api.nvim_get_current_tabpage()
  vim.t[tabnr].tabtype = stl.e.TabTypeEnum.DIFFVIEW_WORKSPACE

  local lyt = {
    tabnr = tabnr,
    layout_type = layout_type,
    changes = create_empty_changes_layout(),
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
    preview_generation = 0,
  } ---@type era.m.diffview.view.workspace.ILayout

  if layout_type == 1 then
    -- Layout 1: changes + sbs
    lyt = M.__create_layout_full__(tabnr)
  elseif layout_type == 2 then
    -- Layout 2: changes only
    lyt = M.__create_layout_changes_only__(tabnr)
  elseif layout_type == 3 then
    -- Layout 3: sbs only
    lyt = M.__create_layout_sbs_only__(tabnr)
  else
    lyt = M.__create_layout_full__(tabnr)
  end

  lyt.layout_type = layout_type

  return lyt
end

---Create full layout: changes + sbs
---@param tabnr                          integer
---@return era.m.diffview.view.workspace.ILayout
function M.__create_layout_full__(tabnr)
  local pivot_winnr = vim.api.nvim_get_current_win()

  -- Create changes window on the left
  vim.cmd("topleft vsplit")
  local changes_anchor_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(changes_anchor_winnr, config.FILETREE_WIDTH)
  local changes = create_changes_layout(changes_anchor_winnr)

  -- Go back to pivot and create sbs windows
  vim.api.nvim_set_current_win(pivot_winnr)

  -- Create sbs using tree-based layout
  local tree = layout_util.sbs("sbs_left", "sbs_right")
  local result = layout_util.create(tree, pivot_winnr)

  local sbs_left_winnr = result.winnrs.sbs_left
  local sbs_right_winnr = result.winnrs.sbs_right

  -- Create null buffers for sbs
  local null_bufnr = pane_sbs.get_null_buffer()
  if sbs_left_winnr then
    vim.api.nvim_win_set_buf(sbs_left_winnr, null_bufnr)
    pane_sbs.apply_sbs_winopts(sbs_left_winnr, "sbs_left")
  end
  if sbs_right_winnr then
    vim.api.nvim_win_set_buf(sbs_right_winnr, null_bufnr)
    pane_sbs.apply_sbs_winopts(sbs_right_winnr, "sbs_right")
  end

  -- Unstaged is the default work queue until the first rendered entry selects its owning pane.
  if changes.unstaged.winnr then
    vim.api.nvim_set_current_win(changes.unstaged.winnr)
  end

  return {
    tabnr = tabnr,
    layout_type = 1,
    changes = changes,
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
    preview_generation = 0,
  }
end

---Create changes only layout
---@param tabnr                          integer
---@return era.m.diffview.view.workspace.ILayout
function M.__create_layout_changes_only__(tabnr)
  local changes = create_changes_layout(vim.api.nvim_get_current_win())

  return {
    tabnr = tabnr,
    layout_type = 2,
    changes = changes,
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
    preview_generation = 0,
  }
end

---Create sbs only layout
---@param tabnr                          integer
---@return era.m.diffview.view.workspace.ILayout
function M.__create_layout_sbs_only__(tabnr)
  local pivot_winnr = vim.api.nvim_get_current_win()

  local tree = layout_util.sbs("sbs_left", "sbs_right")
  local result = layout_util.create(tree, pivot_winnr)

  local sbs_left_winnr = result.winnrs.sbs_left
  local sbs_right_winnr = result.winnrs.sbs_right

  local null_bufnr = pane_sbs.get_null_buffer()
  if sbs_left_winnr then
    vim.api.nvim_win_set_buf(sbs_left_winnr, null_bufnr)
    pane_sbs.apply_sbs_winopts(sbs_left_winnr, "sbs_left")
  end
  if sbs_right_winnr then
    vim.api.nvim_win_set_buf(sbs_right_winnr, null_bufnr)
    pane_sbs.apply_sbs_winopts(sbs_right_winnr, "sbs_right")
  end

  return {
    tabnr = tabnr,
    layout_type = 3,
    changes = create_empty_changes_layout(),
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
    preview_generation = 0,
  }
end

----------------------------------------------------------------------------------------------------
-- Layout management
----------------------------------------------------------------------------------------------------

---Switch to different layout
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param new_layout_type                integer
---@return era.m.diffview.view.workspace.ILayout
function M.switch_layout(lyt, new_layout_type)
  if lyt.layout_type == new_layout_type then
    return lyt
  end

  local tabnr = lyt.tabnr

  -- Close all existing windows
  M.close_windows(lyt)

  -- Create new layout
  vim.api.nvim_set_current_tabpage(tabnr)
  local new_lyt = M.create_layout(new_layout_type)
  new_lyt.tabnr = tabnr

  return new_lyt
end

---Close all windows in layout
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.close_windows(lyt)
  next_preview_generation(lyt)

  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
      pcall(vim.api.nvim_win_close, pane.winnr, true)
    end
    pane.winnr = nil
  end
  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    pcall(vim.api.nvim_win_close, lyt.sbs_left_winnr, true)
  end
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    pcall(vim.api.nvim_win_close, lyt.sbs_right_winnr, true)
  end
end

----------------------------------------------------------------------------------------------------
-- Panel visibility
----------------------------------------------------------------------------------------------------

---Show changes panel (if hidden)
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.show_changes(lyt)
  local staged = lyt.changes.staged
  local unstaged = lyt.changes.unstaged
  if
    staged.winnr
    and vim.api.nvim_win_is_valid(staged.winnr)
    and unstaged.winnr
    and vim.api.nvim_win_is_valid(unstaged.winnr)
  then
    return lyt
  end

  -- The two windows are one logical panel; recover a partially closed panel as a pair.
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
      M.hide_changes(lyt)
      break
    end
  end

  -- Find reference window
  local ref_winnr = lyt.sbs_left_winnr or lyt.sbs_right_winnr
  if not ref_winnr or not vim.api.nvim_win_is_valid(ref_winnr) then
    return lyt
  end

  vim.api.nvim_set_current_win(ref_winnr)
  vim.cmd("topleft vsplit")
  local anchor_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(anchor_winnr, config.FILETREE_WIDTH)
  local result = layout_util.create(layout_util.vertical("staged", "unstaged", 0.5), anchor_winnr)

  for _, stage_type in ipairs({ "staged", "unstaged" }) do
    local pane = M.get_changes_pane(lyt, stage_type)
    pane.winnr = result.winnrs[stage_type]
    if not pane.bufnr or not vim.api.nvim_buf_is_valid(pane.bufnr) then
      pane.bufnr = pane_changes.create_buffer(stage_type)
    end
    if pane.winnr then
      vim.api.nvim_win_set_buf(pane.winnr, pane.bufnr)
      pane_changes.apply_winopts(pane.winnr)
    end
  end
  if staged.winnr then
    lyt.changes.expanded_staged_height = vim.api.nvim_win_get_height(staged.winnr)
  end

  return lyt
end

---Hide changes panel
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.hide_changes(lyt)
  local has_reference = (lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr))
    or (lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr))
  if not has_reference then
    return lyt
  end
  for _, pane in ipairs({ lyt.changes.unstaged, lyt.changes.staged }) do
    if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
      vim.api.nvim_win_hide(pane.winnr)
    end
    pane.winnr = nil
  end
  return lyt
end

---Toggle changes panel visibility
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.toggle_changes(lyt)
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
      return M.hide_changes(lyt)
    end
  end
  return M.show_changes(lyt)
end

----------------------------------------------------------------------------------------------------
-- Focus management
----------------------------------------------------------------------------------------------------

---Focus one Changes pane, defaulting to the Unstaged work queue.
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param stage_type                     stl.m.diffview.StageTypeEnum|nil
function M.focus_changes(lyt, stage_type)
  local preferred = M.get_changes_pane(lyt, stage_type or "unstaged")
  local fallback = M.get_changes_pane(lyt, stage_type == "staged" and "unstaged" or "staged")
  for _, pane in ipairs({ preferred, fallback }) do
    if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
      vim.api.nvim_set_current_win(pane.winnr)
      return
    end
  end
end

---Focus left sbs window
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.focus_left(lyt)
  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    vim.api.nvim_set_current_win(lyt.sbs_left_winnr)
  end
end

---Focus right sbs window
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.focus_right(lyt)
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    vim.api.nvim_set_current_win(lyt.sbs_right_winnr)
  end
end

---Cycle focus: staged -> unstaged -> left -> right -> staged.
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.cycle_focus(lyt)
  local current_winnr = vim.api.nvim_get_current_win()
  local valid = {} ---@type integer[]
  local current_idx = nil ---@type integer|nil

  ---@param winnr integer|nil
  local function append(winnr)
    if winnr and vim.api.nvim_win_is_valid(winnr) then
      valid[#valid + 1] = winnr
      if winnr == current_winnr then
        current_idx = #valid
      end
    end
  end
  append(lyt.changes.staged.winnr)
  append(lyt.changes.unstaged.winnr)
  append(lyt.sbs_left_winnr)
  append(lyt.sbs_right_winnr)

  if #valid == 0 then
    return
  end
  vim.api.nvim_set_current_win(valid[current_idx and (current_idx % #valid) + 1 or 1])
end

----------------------------------------------------------------------------------------------------
-- Validation
----------------------------------------------------------------------------------------------------

---Check if layout is still valid
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return boolean
function M.is_valid(lyt)
  if not vim.api.nvim_tabpage_is_valid(lyt.tabnr) then
    return false
  end

  -- At least one window must be valid
  local has_valid = false
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
      has_valid = true
    end
  end
  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    has_valid = true
  end
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    has_valid = true
  end

  return has_valid
end

----------------------------------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------------------------------

---Destroy layout and close tab
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.destroy(lyt)
  next_preview_generation(lyt)

  -- Restore window options for local buffers in sbs
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    local bufnr = vim.api.nvim_win_get_buf(lyt.sbs_right_winnr)
    pane_sbs.restore_winopts(bufnr)
  end

  -- Clean up Changes buffers.
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
      pcall(vim.api.nvim_buf_delete, pane.bufnr, { force = true })
    end
  end

  -- Close tab if it still exists
  if vim.api.nvim_tabpage_is_valid(lyt.tabnr) then
    local tabs = vim.api.nvim_list_tabpages()
    if #tabs > 1 then
      local tabnr_num = vim.api.nvim_tabpage_get_number(lyt.tabnr)
      pcall(function()
        vim.cmd("tabclose " .. tabnr_num)
      end)
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------------------------------------

---Collapse an empty sibling to its header and restore the prior split when both have entries.
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param staged_count                   integer
---@param unstaged_count                 integer
function M.__sync_changes_heights__(lyt, staged_count, unstaged_count)
  local changes = lyt.changes
  local staged_winnr = changes.staged.winnr
  local unstaged_winnr = changes.unstaged.winnr
  if
    not staged_winnr
    or not vim.api.nvim_win_is_valid(staged_winnr)
    or not unstaged_winnr
    or not vim.api.nvim_win_is_valid(unstaged_winnr)
  then
    return
  end

  local staged_height = vim.api.nvim_win_get_height(staged_winnr)
  local unstaged_height = vim.api.nvim_win_get_height(unstaged_winnr)
  local both_nonempty = staged_count > 0 and unstaged_count > 0
  if changes.both_nonempty then
    changes.expanded_staged_height = staged_height
  end

  if both_nonempty then
    if not changes.both_nonempty then
      local max_staged_height = math.max(1, staged_height + unstaged_height - 1)
      local restored_height =
        math.min(changes.expanded_staged_height or math.floor((staged_height + unstaged_height) / 2), max_staged_height)
      vim.api.nvim_win_set_height(staged_winnr, math.max(1, restored_height))
    end
  elseif staged_count == 0 then
    vim.api.nvim_win_set_height(staged_winnr, 1)
  elseif unstaged_count == 0 then
    vim.api.nvim_win_set_height(unstaged_winnr, 1)
  end
  changes.both_nonempty = both_nonempty
end

---Render the sibling Changes panes from one workspace snapshot.
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.render_changes(ctx)
  local lyt = ctx.layout
  local state = ctx.state
  local entries = state:get_entries()
  local metadata_widths = pane_changes.measure_metadata(entries)
  local counts = { staged = 0, unstaged = 0 } ---@type table<stl.m.diffview.StageTypeEnum, integer>
  for _, entry in ipairs(entries) do
    if entry.stage_type then
      counts[entry.stage_type] = counts[entry.stage_type] + 1
    end
  end

  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
      local panel_width = config.FILETREE_WIDTH
      if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
        panel_width = vim.api.nvim_win_get_width(pane.winnr)
      end
      local result = pane_changes.render(entries, {
        stage_type = pane.stage_type,
        collapsed_dirs = state:get_collapsed_dirs(pane.stage_type),
        metadata_widths = metadata_widths,
        panel_width = panel_width,
      })
      pane_changes.apply_to_buffer(pane.bufnr, result)
    end
  end

  M.__sync_changes_heights__(lyt, counts.staged, counts.unstaged)
end

---Open file entry in sbs view
---@async
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param entry                          era.m.diffview.IFileEntry
---@param token                          ?stl.c.CancellationToken
---@param opts                           era.m.diffview.view.workspace.IOpenEntryOpts|nil
function M.open_entry(ctx, entry, token, opts)
  local lyt = ctx.layout

  if not lyt.sbs_left_winnr or not vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    return
  end
  if not lyt.sbs_right_winnr or not vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    return
  end

  local generation = next_preview_generation(lyt)
  local function is_current()
    return lyt.preview_generation == generation
      and not ctx.state:is_disposed()
      and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr)
      and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)
  end

  pane_sbs.open_diff_entry({
    left_winnr = lyt.sbs_left_winnr,
    right_winnr = lyt.sbs_right_winnr,
    entry = entry,
    token = token,
    is_current = is_current,
    preserve_view = opts and opts.preserve_view,
  })

  if not is_current() then
    return
  end

  local keymap = require("era.m.diffview.view.workspace.keymap")
  keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(lyt.sbs_left_winnr))
  keymap.setup_sbs(ctx, vim.api.nvim_win_get_buf(lyt.sbs_right_winnr))
end

---Clear sbs view
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.clear_sbs(ctx)
  local lyt = ctx.layout
  local generation = next_preview_generation(lyt)

  if
    lyt.sbs_left_winnr
    and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr)
    and lyt.sbs_right_winnr
    and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)
  then
    pane_sbs.clear(lyt.sbs_left_winnr, lyt.sbs_right_winnr, function()
      return lyt.preview_generation == generation
        and not ctx.state:is_disposed()
        and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr)
        and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)
    end)
  end
end

----------------------------------------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------------------------------------

---@type table<integer, era.m.diffview.view.workspace.ILayout>
M.__layouts__ = {}

---Store layout instance
---@param tabnr                          integer
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.set_layout(tabnr, lyt)
  M.__layouts__[tabnr] = lyt
end

---Get layout instance
---@param tabnr                          integer|nil
---@return era.m.diffview.view.workspace.ILayout|nil
function M.get_layout(tabnr)
  tabnr = tabnr or vim.api.nvim_get_current_tabpage()
  return M.__layouts__[tabnr]
end

---Remove layout instance
---@param tabnr                          integer
function M.remove_layout(tabnr)
  M.__layouts__[tabnr] = nil
end

return M
