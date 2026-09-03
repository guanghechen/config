---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.view" ---@type string

local config = require("era.m.diffview.config")
local layout_util = require("era.m.diffview.layout")
local pane_changes = require("era.m.diffview.pane.changes")
local pane_commits = require("era.m.diffview.pane.commits")
local pane_sbs = require("era.m.diffview.pane.sbs")

---Workspace view controller.
---Manages Changes, History, shared preview, and workspace lifecycle.
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
---@field public last_focused_stage_type stl.m.diffview.StageTypeEnum

---@class era.m.diffview.view.workspace.ILayout
---@field public tabnr                   integer
---@field public layout_type             integer                         1=changes+sbs, 2=changes only, 3=sbs only
---@field public changes                 era.m.diffview.view.workspace.IChangesLayout
---@field public history                 era.m.diffview.view.commits.ILayout
---@field public sbs_left_winnr          integer|nil
---@field public sbs_right_winnr         integer|nil
---@field public preview_generation      integer
---@field public preview_source          "changes"|"history"|nil

---@class era.m.diffview.view.workspace.IOpenEntryOpts
---@field public preserve_view           boolean|nil

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return integer
local function next_preview_generation(lyt)
  lyt.preview_generation = (lyt.preview_generation or 0) + 1
  return lyt.preview_generation
end

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param source                         "changes"|"history"|nil
---@return integer
function M.begin_preview(lyt, source)
  lyt.preview_source = source
  return next_preview_generation(lyt)
end

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param generation                     integer
---@return boolean
function M.owns_preview(lyt, generation)
  return lyt.preview_generation == generation and vim.api.nvim_tabpage_is_valid(lyt.tabnr)
end

---@return era.m.diffview.view.workspace.IChangesLayout
local function create_empty_changes_layout()
  return {
    staged = { stage_type = "staged", winnr = nil, bufnr = nil },
    unstaged = { stage_type = "unstaged", winnr = nil, bufnr = nil },
    last_focused_stage_type = "unstaged",
  }
end

---@param ...                            integer|nil
---@return integer|nil
local function first_valid_window(...)
  for index = 1, select("#", ...) do
    local winnr = select(index, ...) ---@type integer|nil
    if winnr and vim.api.nvim_win_is_valid(winnr) then
      return winnr
    end
  end
end

---@param tabnr                          integer
---@return era.m.diffview.view.commits.ILayout
local function create_empty_history_layout(tabnr)
  return {
    tabnr = tabnr,
    layout_type = 2,
    commits_winnr = nil,
    commits_bufnr = nil,
    filetree_winnr = nil,
    filetree_bufnr = nil,
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
    title = "History",
  }
end

---@param history                        era.m.diffview.view.commits.ILayout
---@return integer
local function create_history_buffer(history)
  local bufnr = pane_commits.create_buffer() ---@type integer
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  history.commits_bufnr = bufnr
  return bufnr
end

---@param history                        era.m.diffview.view.commits.ILayout
---@param anchor_winnr                   integer
---@return nil
local function create_history_below(history, anchor_winnr)
  local history_winnr = nil ---@type integer|nil
  vim.api.nvim_win_call(anchor_winnr, function()
    vim.cmd("belowright split")
    history_winnr = vim.api.nvim_get_current_win()
  end)
  if history_winnr == nil then
    return
  end

  history.commits_winnr = history_winnr
  local bufnr = history.commits_bufnr ---@type integer|nil
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = create_history_buffer(history)
  end
  vim.api.nvim_win_set_buf(history_winnr, bufnr)
  pane_commits.apply_winopts(history_winnr)
  vim.api.nvim_win_set_height(history_winnr, config.COMMITS_HEIGHT)
end

---@param changes                        era.m.diffview.view.workspace.IChangesLayout
---@param stage_type                     stl.m.diffview.StageTypeEnum
---@return integer
local function create_changes_buffer(changes, stage_type)
  local bufnr = pane_changes.create_buffer(stage_type) ---@type integer
  vim.api.nvim_create_autocmd("WinEnter", {
    buffer = bufnr,
    callback = function()
      changes.last_focused_stage_type = stage_type
    end,
  })
  return bufnr
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
    pane.bufnr = create_changes_buffer(changes, stage_type)
    if pane.winnr then
      vim.api.nvim_win_set_buf(pane.winnr, pane.bufnr)
      pane_changes.apply_winopts(pane.winnr)
    end
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
    history = create_empty_history_layout(tabnr),
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
    preview_generation = 0,
    preview_source = nil,
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
  vim.api.nvim_win_set_width(changes_anchor_winnr, dot.context.diffview.panel_width:snapshot())
  local changes = create_changes_layout(changes_anchor_winnr)
  local history = create_empty_history_layout(tabnr)
  local history_anchor = changes.unstaged.winnr or changes.staged.winnr ---@type integer|nil
  if history_anchor then
    create_history_below(history, history_anchor)
  end

  -- Go back to pivot and create sbs windows
  vim.api.nvim_set_current_win(pivot_winnr)

  -- Create sbs using tree-based layout
  local tree = layout_util.sbs("sbs_left", "sbs_right")
  local result = layout_util.create(tree, pivot_winnr)

  local sbs_left_winnr = result.winnrs.sbs_left
  local sbs_right_winnr = result.winnrs.sbs_right
  history.sbs_left_winnr = sbs_left_winnr
  history.sbs_right_winnr = sbs_right_winnr

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
    history = history,
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
    preview_generation = 0,
    preview_source = nil,
  }
end

---Create changes only layout
---@param tabnr                          integer
---@return era.m.diffview.view.workspace.ILayout
function M.__create_layout_changes_only__(tabnr)
  local changes = create_changes_layout(vim.api.nvim_get_current_win())
  local history = create_empty_history_layout(tabnr)
  local history_anchor = changes.unstaged.winnr or changes.staged.winnr ---@type integer|nil
  if history_anchor then
    create_history_below(history, history_anchor)
  end

  if changes.unstaged.winnr then
    vim.api.nvim_set_current_win(changes.unstaged.winnr)
  end

  return {
    tabnr = tabnr,
    layout_type = 2,
    changes = changes,
    history = history,
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
    preview_generation = 0,
    preview_source = nil,
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
  local history = create_empty_history_layout(tabnr)
  history.sbs_left_winnr = sbs_left_winnr
  history.sbs_right_winnr = sbs_right_winnr

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
    history = history,
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
    preview_generation = 0,
    preview_source = nil,
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
  if lyt.history.commits_winnr and vim.api.nvim_win_is_valid(lyt.history.commits_winnr) then
    pcall(vim.api.nvim_win_close, lyt.history.commits_winnr, true)
  end
  lyt.history.commits_winnr = nil
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

  -- Recreate Changes above History when it is visible; otherwise restore the left column from SBS.
  local history_winnr = first_valid_window(lyt.history.commits_winnr)
  local ref_winnr = first_valid_window(history_winnr, lyt.sbs_left_winnr, lyt.sbs_right_winnr)
  if not ref_winnr then
    return lyt
  end

  vim.api.nvim_set_current_win(ref_winnr)
  if history_winnr and vim.api.nvim_win_is_valid(history_winnr) then
    vim.cmd("aboveleft split")
  else
    vim.cmd("topleft vsplit")
  end
  local anchor_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(anchor_winnr, dot.context.diffview.panel_width:snapshot())
  local result = layout_util.create(layout_util.vertical("staged", "unstaged", 0.5), anchor_winnr)

  for _, stage_type in ipairs({ "staged", "unstaged" }) do
    local pane = M.get_changes_pane(lyt, stage_type)
    pane.winnr = result.winnrs[stage_type]
    if not pane.bufnr or not vim.api.nvim_buf_is_valid(pane.bufnr) then
      pane.bufnr = create_changes_buffer(lyt.changes, stage_type)
    end
    if pane.winnr then
      vim.api.nvim_win_set_buf(pane.winnr, pane.bufnr)
      pane_changes.apply_winopts(pane.winnr)
    end
  end
  if history_winnr then
    vim.api.nvim_win_set_height(history_winnr, config.COMMITS_HEIGHT)
  end

  return lyt
end

---Hide changes panel
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.hide_changes(lyt)
  local has_reference = (lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr))
    or (lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr))
    or (lyt.history.commits_winnr and vim.api.nvim_win_is_valid(lyt.history.commits_winnr))
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

---Show the repository History pane at the bottom of the workspace navigation column.
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.show_history(lyt)
  local history = lyt.history
  if history.commits_winnr and vim.api.nvim_win_is_valid(history.commits_winnr) then
    return lyt
  end

  local changes_anchor = first_valid_window(lyt.changes.unstaged.winnr, lyt.changes.staged.winnr)
  if changes_anchor then
    create_history_below(history, changes_anchor)
    M.sync_changes_heights(lyt)
    return lyt
  end

  local ref_winnr = first_valid_window(lyt.sbs_left_winnr, lyt.sbs_right_winnr)
  if not ref_winnr then
    return lyt
  end

  vim.api.nvim_set_current_win(ref_winnr)
  vim.cmd("topleft vsplit")
  local history_winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.api.nvim_win_set_width(history_winnr, dot.context.diffview.panel_width:snapshot())
  history.commits_winnr = history_winnr
  local bufnr = history.commits_bufnr ---@type integer|nil
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = create_history_buffer(history)
  end
  vim.api.nvim_win_set_buf(history_winnr, bufnr)
  pane_commits.apply_winopts(history_winnr)
  return lyt
end

---Hide the repository History pane while preserving its buffer and state.
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.hide_history(lyt)
  local has_reference = (lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr))
    or (lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr))
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    has_reference = has_reference or (pane.winnr ~= nil and vim.api.nvim_win_is_valid(pane.winnr))
  end
  if not has_reference then
    return lyt
  end

  local history = lyt.history
  if history.commits_winnr and vim.api.nvim_win_is_valid(history.commits_winnr) then
    vim.api.nvim_win_hide(history.commits_winnr)
  end
  history.commits_winnr = nil
  M.sync_changes_heights(lyt)
  return lyt
end

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.toggle_history(lyt)
  if lyt.history.commits_winnr and vim.api.nvim_win_is_valid(lyt.history.commits_winnr) then
    return M.hide_history(lyt)
  end
  return M.show_history(lyt)
end

---Toggle Changes and History as one workspace sidebar.
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
---@return boolean visible
function M.toggle_sidebar(lyt)
  local visible = lyt.history.commits_winnr ~= nil and vim.api.nvim_win_is_valid(lyt.history.commits_winnr)
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    visible = visible or (pane.winnr ~= nil and vim.api.nvim_win_is_valid(pane.winnr))
  end

  if visible then
    if not first_valid_window(lyt.sbs_left_winnr, lyt.sbs_right_winnr) then
      return lyt, true
    end
    M.hide_changes(lyt)
    M.hide_history(lyt)
    return lyt, false
  end

  M.show_changes(lyt)
  M.show_history(lyt)
  visible = lyt.history.commits_winnr ~= nil and vim.api.nvim_win_is_valid(lyt.history.commits_winnr)
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    visible = visible or (pane.winnr ~= nil and vim.api.nvim_win_is_valid(pane.winnr))
  end
  return lyt, visible
end

----------------------------------------------------------------------------------------------------
-- Focus management
----------------------------------------------------------------------------------------------------

---Focus one Changes pane, defaulting to the last focused sibling.
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param stage_type                     stl.m.diffview.StageTypeEnum|nil
---@return boolean
function M.focus_changes(lyt, stage_type)
  local preferred_stage_type = stage_type or lyt.changes.last_focused_stage_type or "unstaged"
  local fallback_stage_type = preferred_stage_type == "staged" and "unstaged" or "staged"
  local preferred = M.get_changes_pane(lyt, preferred_stage_type)
  local fallback = M.get_changes_pane(lyt, fallback_stage_type)
  for _, pane in ipairs({ preferred, fallback }) do
    if pane.winnr and vim.api.nvim_win_is_valid(pane.winnr) then
      lyt.changes.last_focused_stage_type = pane.stage_type
      vim.api.nvim_set_current_win(pane.winnr)
      return true
    end
  end
  return false
end

---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return boolean
function M.focus_history(lyt)
  local winnr = lyt.history.commits_winnr
  if winnr and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
    return true
  end
  return false
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

---Cycle focus: staged -> unstaged -> History -> left -> right -> staged.
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.cycle_focus(lyt)
  local current_winnr = vim.api.nvim_get_current_win()
  local right_valid = lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)
  if current_winnr == lyt.sbs_right_winnr or (current_winnr == lyt.sbs_left_winnr and not right_valid) then
    if M.focus_changes(lyt) then
      return
    end
  end
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
  append(lyt.history.commits_winnr)
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
  if lyt.history.commits_winnr and vim.api.nvim_win_is_valid(lyt.history.commits_winnr) then
    has_valid = true
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
  if lyt.history.commits_bufnr and vim.api.nvim_buf_is_valid(lyt.history.commits_bufnr) then
    pcall(vim.api.nvim_buf_delete, lyt.history.commits_bufnr, { force = true })
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

---Project the complete workspace snapshot into the entries visible in the Changes panes.
---@param entries                        era.m.diffview.IFileEntry[]
---@return era.m.diffview.IFileEntry[]
function M.get_visible_entries(entries)
  if dot.context.diffview.flag_untracked:snapshot() then
    return entries
  end

  local visible = {} ---@type era.m.diffview.IFileEntry[]
  for _, entry in ipairs(entries) do
    if entry.status ~= "?" then
      visible[#visible + 1] = entry
    end
  end
  return visible
end

---@class era.m.diffview.view.workspace.IHeightAllocation
---@field public staged                 integer
---@field public unstaged               integer
---@field public history                integer

---Allocate the navigation column: content-fit smaller Changes panes, then give remaining space to
---History. When content overflows, preserve History's minimum and split the Changes budget fairly.
---@param total_height                   integer
---@param staged_lines                   integer
---@param unstaged_lines                 integer
---@param history_min_height             integer|nil
---@return era.m.diffview.view.workspace.IHeightAllocation
function M.__allocate_changes_heights__(total_height, staged_lines, unstaged_lines, history_min_height)
  total_height = math.max(2, total_height)
  local staged_required = math.max(1, staged_lines) ---@type integer
  local unstaged_required = math.max(1, unstaged_lines) ---@type integer
  local history_height = 0 ---@type integer
  local changes_budget = total_height ---@type integer

  if history_min_height ~= nil and total_height >= 3 then
    local staged_floor = math.min(staged_required, 2) ---@type integer
    local unstaged_floor = math.min(unstaged_required, 2) ---@type integer
    local history_ceiling = math.max(1, total_height - staged_floor - unstaged_floor) ---@type integer
    history_height = math.min(math.max(1, history_min_height), history_ceiling)
    changes_budget = total_height - history_height
  end

  if staged_required + unstaged_required <= changes_budget then
    if history_min_height ~= nil then
      history_height = total_height - staged_required - unstaged_required
    else
      local slack = changes_budget - staged_required - unstaged_required ---@type integer
      if staged_required >= unstaged_required then
        staged_required = staged_required + slack
      else
        unstaged_required = unstaged_required + slack
      end
    end
    return { staged = staged_required, unstaged = unstaged_required, history = history_height }
  end

  local half_budget = math.floor(changes_budget / 2) ---@type integer
  if staged_required <= unstaged_required then
    local staged_height = math.min(staged_required, half_budget) ---@type integer
    return {
      staged = staged_height,
      unstaged = changes_budget - staged_height,
      history = history_height,
    }
  end

  local unstaged_height = math.min(unstaged_required, half_budget) ---@type integer
  return {
    staged = changes_budget - unstaged_height,
    unstaged = unstaged_height,
    history = history_height,
  }
end

---Synchronize the navigation column from the rendered Changes line counts.
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param staged_lines                   integer
---@param unstaged_lines                 integer
function M.__sync_changes_heights__(lyt, staged_lines, unstaged_lines)
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

  local history_winnr = lyt.history and lyt.history.commits_winnr or nil ---@type integer|nil
  if history_winnr and not vim.api.nvim_win_is_valid(history_winnr) then
    history_winnr = nil
  end
  local total_height = vim.api.nvim_win_get_height(staged_winnr) + vim.api.nvim_win_get_height(unstaged_winnr)
  if history_winnr then
    total_height = total_height + vim.api.nvim_win_get_height(history_winnr)
  end

  local allocation = M.__allocate_changes_heights__(
    total_height,
    staged_lines,
    unstaged_lines,
    history_winnr and config.COMMITS_HEIGHT or nil
  )
  vim.api.nvim_win_set_height(staged_winnr, allocation.staged)
  if history_winnr then
    vim.api.nvim_win_set_height(history_winnr, allocation.history)
  end
end

---Synchronize Changes split heights without rebuilding either pane buffer.
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.sync_changes_heights(lyt)
  local line_counts = { staged = 1, unstaged = 1 } ---@type table<stl.m.diffview.StageTypeEnum, integer>
  for _, pane in ipairs(M.get_changes_panes(lyt)) do
    if pane.bufnr and vim.api.nvim_buf_is_valid(pane.bufnr) then
      line_counts[pane.stage_type] = vim.api.nvim_buf_line_count(pane.bufnr)
    end
  end
  M.__sync_changes_heights__(lyt, line_counts.staged, line_counts.unstaged)
end

---Render the sibling Changes panes from one workspace snapshot.
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.render_changes(ctx)
  local lyt = ctx.layout
  local state = ctx.state
  local entries = M.get_visible_entries(state:get_entries())
  local metadata_widths = pane_changes.measure_metadata(entries)

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

  M.sync_changes_heights(lyt)
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

  local generation = M.begin_preview(lyt, "changes")
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
    get_fold_unchanged = function()
      return ctx.state:get_fold_unchanged()
    end,
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
  local generation = M.begin_preview(lyt, "changes")

  if
    lyt.sbs_left_winnr
    and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr)
    and lyt.sbs_right_winnr
    and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)
  then
    pane_sbs.clear(lyt.sbs_left_winnr, lyt.sbs_right_winnr, {
      is_current = function()
        return lyt.preview_generation == generation
          and not ctx.state:is_disposed()
          and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr)
          and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)
      end,
      get_fold_unchanged = function()
        return ctx.state:get_fold_unchanged()
      end,
    })
  end
end

---Compose the repository History controller against the workspace-owned layout and SBS generation.
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@param workspace_state                era.m.diffview.view.workspace.State
---@param history_state                  era.m.diffview.view.commits.State
---@return era.m.diffview.view.commits.IContext
function M.history_context(lyt, workspace_state, history_state)
  local history ---@type era.m.diffview.view.commits.IContext
  history = {
    layout = lyt.history,
    state = history_state,
    begin_preview = function()
      local generation = M.begin_preview(lyt, "history") ---@type integer
      return function()
        return M.owns_preview(lyt, generation)
          and not workspace_state:is_disposed()
          and not history_state:is_disposed()
      end
    end,
    setup_sbs = function(bufnr)
      require("era.m.diffview.view.workspace.keymap").setup_sbs({
        layout = lyt,
        state = workspace_state,
        history = history,
      }, bufnr)
    end,
    render_winline = function()
      require("era.m.diffview.view.workspace.winline").render(history)
    end,
  }
  return history
end

----------------------------------------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------------------------------------

---@type table<integer, era.m.diffview.view.workspace.ILayout>
M.__layouts__ = {}

---@type table<integer, integer>
M.__layout_cleanup_autocmds__ = {}

---Store layout instance
---@param tabnr                          integer
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.set_layout(tabnr, lyt)
  M.__layouts__[tabnr] = lyt
  if M.__layout_cleanup_autocmds__[tabnr] then
    return
  end

  M.__layout_cleanup_autocmds__[tabnr] = vim.api.nvim_create_autocmd("TabClosed", {
    desc = "diffview: release closed workspace layout",
    callback = function()
      if vim.api.nvim_tabpage_is_valid(tabnr) then
        return
      end

      M.__layout_cleanup_autocmds__[tabnr] = nil
      local closed_layout = M.__layouts__[tabnr]
      M.__layouts__[tabnr] = nil
      if closed_layout then
        M.destroy(closed_layout)
      end
      return true
    end,
  })
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
  local autocmd_id = M.__layout_cleanup_autocmds__[tabnr]
  M.__layout_cleanup_autocmds__[tabnr] = nil
  if autocmd_id then
    pcall(vim.api.nvim_del_autocmd, autocmd_id)
  end
end

return M
