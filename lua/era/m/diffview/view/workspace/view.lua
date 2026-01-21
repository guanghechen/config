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

---@class era.m.diffview.view.workspace.ILayout
---@field public tabnr                   integer
---@field public layout_type             integer                         1=changes+sbs, 2=changes only, 3=sbs only
---@field public changes_winnr           integer|nil
---@field public changes_bufnr           integer|nil
---@field public sbs_left_winnr          integer|nil
---@field public sbs_right_winnr         integer|nil

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
    changes_winnr = nil,
    changes_bufnr = nil,
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
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
  local changes_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(changes_winnr, config.FILETREE_WIDTH)

  -- Create changes buffer
  local changes_bufnr = pane_changes.create_buffer()
  vim.api.nvim_win_set_buf(changes_winnr, changes_bufnr)

  -- Apply panel window options
  pane_changes.apply_winopts(changes_winnr)

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

  -- Focus changes pane
  vim.api.nvim_set_current_win(changes_winnr)

  return {
    tabnr = tabnr,
    layout_type = 1,
    changes_winnr = changes_winnr,
    changes_bufnr = changes_bufnr,
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
  }
end

---Create changes only layout
---@param tabnr                          integer
---@return era.m.diffview.view.workspace.ILayout
function M.__create_layout_changes_only__(tabnr)
  local changes_winnr = vim.api.nvim_get_current_win()
  local changes_bufnr = pane_changes.create_buffer()

  vim.api.nvim_win_set_buf(changes_winnr, changes_bufnr)
  pane_changes.apply_winopts(changes_winnr)

  return {
    tabnr = tabnr,
    layout_type = 2,
    changes_winnr = changes_winnr,
    changes_bufnr = changes_bufnr,
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
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
    changes_winnr = nil,
    changes_bufnr = nil,
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
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
  if lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
    pcall(vim.api.nvim_win_close, lyt.changes_winnr, true)
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
  if lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
    return lyt
  end

  -- Find reference window
  local ref_winnr = lyt.sbs_left_winnr or lyt.sbs_right_winnr
  if not ref_winnr or not vim.api.nvim_win_is_valid(ref_winnr) then
    return lyt
  end

  -- Create buffer if needed
  if not lyt.changes_bufnr or not vim.api.nvim_buf_is_valid(lyt.changes_bufnr) then
    lyt.changes_bufnr = pane_changes.create_buffer()
  end

  vim.api.nvim_set_current_win(ref_winnr)
  vim.cmd("topleft vsplit")
  local changes_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(changes_winnr, config.FILETREE_WIDTH)
  vim.api.nvim_win_set_buf(changes_winnr, lyt.changes_bufnr)
  pane_changes.apply_winopts(changes_winnr)

  lyt.changes_winnr = changes_winnr

  return lyt
end

---Hide changes panel
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.hide_changes(lyt)
  if lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
    vim.api.nvim_win_hide(lyt.changes_winnr)
    lyt.changes_winnr = nil
  end
  return lyt
end

---Toggle changes panel visibility
---@param lyt                            era.m.diffview.view.workspace.ILayout
---@return era.m.diffview.view.workspace.ILayout
function M.toggle_changes(lyt)
  if lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
    return M.hide_changes(lyt)
  else
    return M.show_changes(lyt)
  end
end

----------------------------------------------------------------------------------------------------
-- Focus management
----------------------------------------------------------------------------------------------------

---Focus changes panel
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.focus_changes(lyt)
  if lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
    vim.api.nvim_set_current_win(lyt.changes_winnr)
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

---Cycle focus: changes -> left -> right -> changes
---@param lyt                            era.m.diffview.view.workspace.ILayout
function M.cycle_focus(lyt)
  local current_winnr = vim.api.nvim_get_current_win()

  local changes_valid = lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr)
  local left_valid = lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr)
  local right_valid = lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)

  if current_winnr == lyt.changes_winnr then
    if left_valid then
      vim.api.nvim_set_current_win(lyt.sbs_left_winnr)
    elseif right_valid then
      vim.api.nvim_set_current_win(lyt.sbs_right_winnr)
    end
  elseif current_winnr == lyt.sbs_left_winnr then
    if right_valid then
      vim.api.nvim_set_current_win(lyt.sbs_right_winnr)
    elseif changes_valid then
      vim.api.nvim_set_current_win(lyt.changes_winnr)
    end
  elseif current_winnr == lyt.sbs_right_winnr then
    if changes_valid then
      vim.api.nvim_set_current_win(lyt.changes_winnr)
    elseif left_valid then
      vim.api.nvim_set_current_win(lyt.sbs_left_winnr)
    end
  else
    -- Current window not in layout
    if changes_valid then
      vim.api.nvim_set_current_win(lyt.changes_winnr)
    elseif left_valid then
      vim.api.nvim_set_current_win(lyt.sbs_left_winnr)
    elseif right_valid then
      vim.api.nvim_set_current_win(lyt.sbs_right_winnr)
    end
  end
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
  if lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
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
  -- Restore window options for local buffers in sbs
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    local bufnr = vim.api.nvim_win_get_buf(lyt.sbs_right_winnr)
    pane_sbs.restore_winopts(bufnr)
  end

  -- Clean up changes buffer
  if lyt.changes_bufnr and vim.api.nvim_buf_is_valid(lyt.changes_bufnr) then
    pcall(vim.api.nvim_buf_delete, lyt.changes_bufnr, { force = true })
  end

  -- Close tab if it still exists
  if vim.api.nvim_tabpage_is_valid(lyt.tabnr) then
    local tabs = vim.api.nvim_list_tabpages()
    if #tabs > 1 then
      local tabnr_num = vim.api.nvim_tabpage_get_number(lyt.tabnr)
      pcall(function() vim.cmd("tabclose " .. tabnr_num) end)
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------------------------------------

---Render changes pane
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.render_changes(ctx)
  local lyt = ctx.layout
  local state = ctx.state

  if not lyt.changes_bufnr or not vim.api.nvim_buf_is_valid(lyt.changes_bufnr) then
    return
  end

  local entries = state:get_entries()
  local collapsed_dirs = state:get_collapsed_dirs()
  local panel_width = config.FILETREE_WIDTH

  if lyt.changes_winnr and vim.api.nvim_win_is_valid(lyt.changes_winnr) then
    panel_width = vim.api.nvim_win_get_width(lyt.changes_winnr)
  end

  local result = pane_changes.render(entries, {
    collapsed_dirs = collapsed_dirs,
    panel_width = panel_width,
  })

  pane_changes.apply_to_buffer(lyt.changes_bufnr, result)
end

---Open file entry in sbs view
---@async
---@param ctx                            era.m.diffview.view.workspace.IContext
---@param entry                          era.m.diffview.IFileEntry
---@param token                          ?stl.c.CancellationToken
function M.open_entry(ctx, entry, token)
  local lyt = ctx.layout

  if not lyt.sbs_left_winnr or not vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    return
  end
  if not lyt.sbs_right_winnr or not vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    return
  end

  pane_sbs.open_diff_entry({
    left_winnr = lyt.sbs_left_winnr,
    right_winnr = lyt.sbs_right_winnr,
    entry = entry,
    token = token,
  })
end

---Clear sbs view
---@param ctx                            era.m.diffview.view.workspace.IContext
function M.clear_sbs(ctx)
  local lyt = ctx.layout

  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) and lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    pane_sbs.clear(lyt.sbs_left_winnr, lyt.sbs_right_winnr)
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
