---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.commits.view" ---@type string

local config = require("era.m.diffview.config")
local layout_util = require("era.m.diffview.layout")
local pane_commits = require("era.m.diffview.pane.commits")
local pane_filetree = require("era.m.diffview.pane.filetree")
local pane_sbs = require("era.m.diffview.pane.sbs")

---Commits view controller.
---Manages layout, pane composition, and lifecycle for Git Log view.
---@class era.m.diffview.view.commits.view
local M = {}

----------------------------------------------------------------------------------------------------
-- Type definitions
----------------------------------------------------------------------------------------------------

---@class era.m.diffview.view.commits.ILayout
---@field public tabnr                   integer
---@field public layout_type             integer                         1-5 layout types
---@field public commits_winnr           integer|nil
---@field public commits_bufnr           integer|nil
---@field public filetree_winnr          integer|nil
---@field public filetree_bufnr          integer|nil
---@field public sbs_left_winnr          integer|nil
---@field public sbs_right_winnr         integer|nil
---@field public title                   string|nil

---@class era.m.diffview.view.commits.IContext
---@field public layout                  era.m.diffview.view.commits.ILayout
---@field public state                   era.m.diffview.view.commits.State
---@field public begin_preview           (fun(): fun(): boolean)|nil
---@field public setup_sbs               (fun(bufnr: integer): nil)|nil
---@field public render_winline          (fun(): nil)|nil

----------------------------------------------------------------------------------------------------
-- Layout creation
----------------------------------------------------------------------------------------------------

---Create commits layout in new tab
---Layout types:
---  1 = commits_top: [commits] / [sbs_left | sbs_right]
---  2 = commits_left: [commits | sbs_left | sbs_right]
---  3 = sbs_only: [sbs_left | sbs_right]
---  4 = commits_only: [commits]
---  5 = commits_filetree: [commits | filetree]
---@param layout_type                    integer|nil                     defaults to 1
---@return era.m.diffview.view.commits.ILayout
function M.create_layout(layout_type)
  layout_type = layout_type or 1

  -- Create new tab at the end
  vim.cmd("$tabnew")
  local tabnr = vim.api.nvim_get_current_tabpage()
  vim.t[tabnr].tabtype = stl.e.TabTypeEnum.DIFFVIEW_COMMITS

  local lyt = {
    tabnr = tabnr,
    layout_type = layout_type,
    commits_winnr = nil,
    commits_bufnr = nil,
    filetree_winnr = nil,
    filetree_bufnr = nil,
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
  } ---@type era.m.diffview.view.commits.ILayout

  if layout_type == 1 then
    lyt = M.__create_layout_commits_top__(tabnr)
  elseif layout_type == 2 then
    lyt = M.__create_layout_commits_left__(tabnr)
  elseif layout_type == 3 then
    lyt = M.__create_layout_sbs_only__(tabnr)
  elseif layout_type == 4 then
    lyt = M.__create_layout_commits_only__(tabnr)
  elseif layout_type == 5 then
    lyt = M.__create_layout_commits_filetree__(tabnr)
  else
    lyt = M.__create_layout_commits_top__(tabnr)
  end

  lyt.layout_type = layout_type

  return lyt
end

---Create layout 1: commits on top [commits] / [sbs_left | sbs_right]
---@param tabnr                          integer
---@return era.m.diffview.view.commits.ILayout
function M.__create_layout_commits_top__(tabnr)
  local pivot_winnr = vim.api.nvim_get_current_win()

  -- Create commits window on top
  vim.cmd("topleft split")
  local commits_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(commits_winnr, config.COMMITS_HEIGHT)

  -- Create commits buffer
  local commits_bufnr = pane_commits.create_buffer()
  vim.api.nvim_win_set_buf(commits_winnr, commits_bufnr)
  pane_commits.apply_winopts(commits_winnr)

  -- Go back to pivot and create sbs windows
  vim.api.nvim_set_current_win(pivot_winnr)

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

  -- Focus commits pane
  vim.api.nvim_set_current_win(commits_winnr)

  return {
    tabnr = tabnr,
    layout_type = 1,
    commits_winnr = commits_winnr,
    commits_bufnr = commits_bufnr,
    filetree_winnr = nil,
    filetree_bufnr = nil,
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
  }
end

---Create layout 2: commits on left [commits | sbs_left | sbs_right]
---@param tabnr                          integer
---@return era.m.diffview.view.commits.ILayout
function M.__create_layout_commits_left__(tabnr)
  local pivot_winnr = vim.api.nvim_get_current_win()

  -- Create commits window on the left
  vim.cmd("topleft vsplit")
  local commits_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(commits_winnr, config.COMMITS_WIDTH)

  -- Create commits buffer
  local commits_bufnr = pane_commits.create_buffer()
  vim.api.nvim_win_set_buf(commits_winnr, commits_bufnr)
  pane_commits.apply_winopts(commits_winnr)

  -- Go back to pivot and create sbs windows
  vim.api.nvim_set_current_win(pivot_winnr)

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

  -- Focus commits pane
  vim.api.nvim_set_current_win(commits_winnr)

  return {
    tabnr = tabnr,
    layout_type = 2,
    commits_winnr = commits_winnr,
    commits_bufnr = commits_bufnr,
    filetree_winnr = nil,
    filetree_bufnr = nil,
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
  }
end

---Create layout 3: sbs only [sbs_left | sbs_right]
---@param tabnr                          integer
---@return era.m.diffview.view.commits.ILayout
function M.__create_layout_sbs_only__(tabnr)
  local pivot_winnr = vim.api.nvim_get_current_win()

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

  return {
    tabnr = tabnr,
    layout_type = 3,
    commits_winnr = nil,
    commits_bufnr = nil,
    filetree_winnr = nil,
    filetree_bufnr = nil,
    sbs_left_winnr = sbs_left_winnr,
    sbs_right_winnr = sbs_right_winnr,
  }
end

---Create layout 4: commits only [commits]
---@param tabnr                          integer
---@return era.m.diffview.view.commits.ILayout
function M.__create_layout_commits_only__(tabnr)
  local pivot_winnr = vim.api.nvim_get_current_win()

  -- Create commits buffer in current window
  local commits_bufnr = pane_commits.create_buffer()
  vim.api.nvim_win_set_buf(pivot_winnr, commits_bufnr)
  pane_commits.apply_winopts(pivot_winnr)

  return {
    tabnr = tabnr,
    layout_type = 4,
    commits_winnr = pivot_winnr,
    commits_bufnr = commits_bufnr,
    filetree_winnr = nil,
    filetree_bufnr = nil,
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
  }
end

---Create layout 5: commits with filetree [commits | filetree]
---@param tabnr                          integer
---@return era.m.diffview.view.commits.ILayout
function M.__create_layout_commits_filetree__(tabnr)
  local pivot_winnr = vim.api.nvim_get_current_win()

  -- Create commits buffer in current window
  local commits_bufnr = pane_commits.create_buffer()
  vim.api.nvim_win_set_buf(pivot_winnr, commits_bufnr)
  pane_commits.apply_winopts(pivot_winnr)
  local commits_winnr = pivot_winnr

  -- Create filetree window on the right
  vim.cmd("rightbelow vsplit")
  local filetree_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(filetree_winnr, config.FILETREE_WIDTH)

  -- Create filetree buffer
  local filetree_bufnr = pane_filetree.create_buffer()
  vim.api.nvim_win_set_buf(filetree_winnr, filetree_bufnr)
  pane_filetree.apply_winopts(filetree_winnr)

  -- Focus commits pane
  vim.api.nvim_set_current_win(commits_winnr)

  return {
    tabnr = tabnr,
    layout_type = 5,
    commits_winnr = commits_winnr,
    commits_bufnr = commits_bufnr,
    filetree_winnr = filetree_winnr,
    filetree_bufnr = filetree_bufnr,
    sbs_left_winnr = nil,
    sbs_right_winnr = nil,
  }
end

----------------------------------------------------------------------------------------------------
-- Layout management
----------------------------------------------------------------------------------------------------

---Switch to different layout
---@param lyt                            era.m.diffview.view.commits.ILayout
---@param new_layout_type                integer
---@return era.m.diffview.view.commits.ILayout
function M.switch_layout(lyt, new_layout_type)
  if lyt.layout_type == new_layout_type then
    return lyt
  end

  local tabnr = lyt.tabnr

  -- Ensure we're in the correct tab
  vim.api.nvim_set_current_tabpage(tabnr)

  -- Create a temporary buffer to keep the tab alive while we close windows
  local temp_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = temp_bufnr })

  -- Get current window and set temp buffer to keep tab alive
  local current_winnr = vim.api.nvim_get_current_win()
  local original_bufnr = vim.api.nvim_win_get_buf(current_winnr)
  vim.api.nvim_win_set_buf(current_winnr, temp_bufnr)

  -- Close all windows except current one
  local winnrs_to_close = {}
  if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) and lyt.commits_winnr ~= current_winnr then
    table.insert(winnrs_to_close, lyt.commits_winnr)
  end
  if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) and lyt.filetree_winnr ~= current_winnr then
    table.insert(winnrs_to_close, lyt.filetree_winnr)
  end
  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) and lyt.sbs_left_winnr ~= current_winnr then
    table.insert(winnrs_to_close, lyt.sbs_left_winnr)
  end
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) and lyt.sbs_right_winnr ~= current_winnr then
    table.insert(winnrs_to_close, lyt.sbs_right_winnr)
  end

  for _, winnr in ipairs(winnrs_to_close) do
    pcall(vim.api.nvim_win_close, winnr, true)
  end

  -- Delete original buffer if it was a scratch buffer (not a real file)
  if original_bufnr and vim.api.nvim_buf_is_valid(original_bufnr) then
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = original_bufnr })
    if buftype == "nofile" then
      pcall(vim.api.nvim_buf_delete, original_bufnr, { force = true })
    end
  end

  -- Create new layout in the existing tab (current_winnr is the pivot)
  local new_lyt ---@type era.m.diffview.view.commits.ILayout
  if new_layout_type == 1 then
    new_lyt = M.__create_layout_commits_top__(tabnr)
  elseif new_layout_type == 2 then
    new_lyt = M.__create_layout_commits_left__(tabnr)
  elseif new_layout_type == 3 then
    new_lyt = M.__create_layout_sbs_only__(tabnr)
  elseif new_layout_type == 4 then
    new_lyt = M.__create_layout_commits_only__(tabnr)
  elseif new_layout_type == 5 then
    new_lyt = M.__create_layout_commits_filetree__(tabnr)
  else
    new_lyt = M.__create_layout_commits_top__(tabnr)
  end

  -- Close the temporary pivot window (it's no longer the current window after layout creation)
  if vim.api.nvim_win_is_valid(current_winnr) then
    -- Check if the window still has the temp buffer
    local win_buf = vim.api.nvim_win_get_buf(current_winnr)
    if win_buf == temp_bufnr then
      pcall(vim.api.nvim_win_close, current_winnr, true)
    end
  end

  -- Clean up temp buffer if still exists
  if vim.api.nvim_buf_is_valid(temp_bufnr) then
    pcall(vim.api.nvim_buf_delete, temp_bufnr, { force = true })
  end

  new_lyt.tabnr = tabnr
  new_lyt.layout_type = new_layout_type

  return new_lyt
end

---Close all windows in layout
---@param lyt                            era.m.diffview.view.commits.ILayout
function M.close_windows(lyt)
  if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
    pcall(vim.api.nvim_win_close, lyt.commits_winnr, true)
  end
  if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
    pcall(vim.api.nvim_win_close, lyt.filetree_winnr, true)
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

---Show commits panel (if hidden)
---@param ctx                            era.m.diffview.view.commits.IContext
---@return era.m.diffview.view.commits.ILayout
function M.show_commits(ctx)
  local lyt = ctx.layout
  if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
    return lyt
  end

  -- Find reference window
  local ref_winnr = lyt.filetree_winnr or lyt.sbs_left_winnr or lyt.sbs_right_winnr
  if not ref_winnr or not vim.api.nvim_win_is_valid(ref_winnr) then
    return lyt
  end

  -- Create buffer if needed
  if not lyt.commits_bufnr or not vim.api.nvim_buf_is_valid(lyt.commits_bufnr) then
    lyt.commits_bufnr = pane_commits.create_buffer()
  end

  vim.api.nvim_set_current_win(ref_winnr)
  vim.cmd("topleft vsplit")
  local commits_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(commits_winnr, config.COMMITS_WIDTH)
  vim.api.nvim_win_set_buf(commits_winnr, lyt.commits_bufnr)
  pane_commits.apply_winopts(commits_winnr)

  lyt.commits_winnr = commits_winnr
  require("era.m.diffview.view.commits.keymap").setup_commits(ctx)

  return lyt
end

---Hide commits panel
---@param lyt                            era.m.diffview.view.commits.ILayout
---@return era.m.diffview.view.commits.ILayout
function M.hide_commits(lyt)
  local has_reference = (lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr))
    or (lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr))
    or (lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr))
  if not has_reference then
    return lyt
  end
  if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
    vim.api.nvim_win_hide(lyt.commits_winnr)
    lyt.commits_winnr = nil
  end
  return lyt
end

---Toggle commits panel visibility
---@param ctx                            era.m.diffview.view.commits.IContext
---@return era.m.diffview.view.commits.ILayout
function M.toggle_commits(ctx)
  local lyt = ctx.layout
  if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
    return M.hide_commits(lyt)
  else
    return M.show_commits(ctx)
  end
end

---Show filetree panel (if hidden)
---@param ctx                            era.m.diffview.view.commits.IContext
---@return era.m.diffview.view.commits.ILayout
function M.show_filetree(ctx)
  local lyt = ctx.layout
  if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
    return lyt
  end

  -- Find reference window
  local ref_winnr = lyt.commits_winnr or lyt.sbs_left_winnr or lyt.sbs_right_winnr
  if not ref_winnr or not vim.api.nvim_win_is_valid(ref_winnr) then
    return lyt
  end

  -- Create buffer if needed
  if not lyt.filetree_bufnr or not vim.api.nvim_buf_is_valid(lyt.filetree_bufnr) then
    lyt.filetree_bufnr = pane_filetree.create_buffer()
  end

  vim.api.nvim_set_current_win(ref_winnr)
  vim.cmd("rightbelow vsplit")
  local filetree_winnr = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(filetree_winnr, config.FILETREE_WIDTH)
  vim.api.nvim_win_set_buf(filetree_winnr, lyt.filetree_bufnr)
  pane_filetree.apply_winopts(filetree_winnr)

  lyt.filetree_winnr = filetree_winnr
  require("era.m.diffview.view.commits.keymap").setup_filetree(ctx)

  return lyt
end

---Hide filetree panel
---@param lyt                            era.m.diffview.view.commits.ILayout
---@return era.m.diffview.view.commits.ILayout
function M.hide_filetree(lyt)
  if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
    vim.api.nvim_win_hide(lyt.filetree_winnr)
    lyt.filetree_winnr = nil
  end
  return lyt
end

---Toggle filetree panel visibility
---@param ctx                            era.m.diffview.view.commits.IContext
---@return era.m.diffview.view.commits.ILayout
function M.toggle_filetree(ctx)
  local lyt = ctx.layout
  if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
    return M.hide_filetree(lyt)
  else
    return M.show_filetree(ctx)
  end
end

----------------------------------------------------------------------------------------------------
-- Focus management
----------------------------------------------------------------------------------------------------

---Focus commits panel
---@param lyt                            era.m.diffview.view.commits.ILayout
function M.focus_commits(lyt)
  if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
    vim.api.nvim_set_current_win(lyt.commits_winnr)
  end
end

---Focus filetree panel
---@param lyt                            era.m.diffview.view.commits.ILayout
function M.focus_filetree(lyt)
  if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
    vim.api.nvim_set_current_win(lyt.filetree_winnr)
  end
end

---Focus left sbs window
---@param lyt                            era.m.diffview.view.commits.ILayout
function M.focus_left(lyt)
  if lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    vim.api.nvim_set_current_win(lyt.sbs_left_winnr)
  end
end

---Focus right sbs window
---@param lyt                            era.m.diffview.view.commits.ILayout
function M.focus_right(lyt)
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    vim.api.nvim_set_current_win(lyt.sbs_right_winnr)
  end
end

---Cycle focus: commits -> filetree -> left -> right -> commits
---@param lyt                            era.m.diffview.view.commits.ILayout
function M.cycle_focus(lyt)
  local current_winnr = vim.api.nvim_get_current_win()

  local commits_valid = lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr)
  local filetree_valid = lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr)
  local left_valid = lyt.sbs_left_winnr and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr)
  local right_valid = lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)

  if current_winnr == lyt.commits_winnr then
    if filetree_valid then
      vim.api.nvim_set_current_win(lyt.filetree_winnr)
    elseif left_valid then
      vim.api.nvim_set_current_win(lyt.sbs_left_winnr)
    elseif right_valid then
      vim.api.nvim_set_current_win(lyt.sbs_right_winnr)
    end
  elseif current_winnr == lyt.filetree_winnr then
    if left_valid then
      vim.api.nvim_set_current_win(lyt.sbs_left_winnr)
    elseif right_valid then
      vim.api.nvim_set_current_win(lyt.sbs_right_winnr)
    elseif commits_valid then
      vim.api.nvim_set_current_win(lyt.commits_winnr)
    end
  elseif current_winnr == lyt.sbs_left_winnr then
    if right_valid then
      vim.api.nvim_set_current_win(lyt.sbs_right_winnr)
    elseif commits_valid then
      vim.api.nvim_set_current_win(lyt.commits_winnr)
    elseif filetree_valid then
      vim.api.nvim_set_current_win(lyt.filetree_winnr)
    end
  elseif current_winnr == lyt.sbs_right_winnr then
    if commits_valid then
      vim.api.nvim_set_current_win(lyt.commits_winnr)
    elseif filetree_valid then
      vim.api.nvim_set_current_win(lyt.filetree_winnr)
    elseif left_valid then
      vim.api.nvim_set_current_win(lyt.sbs_left_winnr)
    end
  else
    -- Current window not in layout
    if commits_valid then
      vim.api.nvim_set_current_win(lyt.commits_winnr)
    elseif filetree_valid then
      vim.api.nvim_set_current_win(lyt.filetree_winnr)
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
---@param lyt                            era.m.diffview.view.commits.ILayout
---@return boolean
function M.is_valid(lyt)
  if not vim.api.nvim_tabpage_is_valid(lyt.tabnr) then
    return false
  end

  -- At least one window must be valid
  local has_valid = false
  if lyt.commits_winnr and vim.api.nvim_win_is_valid(lyt.commits_winnr) then
    has_valid = true
  end
  if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
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
---@param lyt                            era.m.diffview.view.commits.ILayout
function M.destroy(lyt)
  -- Restore window options for local buffers in sbs
  if lyt.sbs_right_winnr and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    local bufnr = vim.api.nvim_win_get_buf(lyt.sbs_right_winnr)
    pane_sbs.restore_winopts(bufnr)
  end

  -- Clean up commits buffer
  if lyt.commits_bufnr and vim.api.nvim_buf_is_valid(lyt.commits_bufnr) then
    pcall(vim.api.nvim_buf_delete, lyt.commits_bufnr, { force = true })
  end

  -- Clean up filetree buffer
  if lyt.filetree_bufnr and vim.api.nvim_buf_is_valid(lyt.filetree_bufnr) then
    pcall(vim.api.nvim_buf_delete, lyt.filetree_bufnr, { force = true })
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

---Render commits pane
---@param ctx                            era.m.diffview.view.commits.IContext
function M.render_commits(ctx)
  local lyt = ctx.layout
  local state = ctx.state

  if not lyt.commits_bufnr or not vim.api.nvim_buf_is_valid(lyt.commits_bufnr) then
    return
  end

  local commits = state:get_commits()
  local expanded = state:get_expanded_commits()
  local layout_type = lyt.layout_type or 1

  local result = pane_commits.render(commits, expanded, { layout = layout_type })
  pane_commits.apply_to_buffer(lyt.commits_bufnr, result)
  if ctx.render_winline then
    ctx.render_winline()
  end
end

---Render filetree pane (for expanded commit files)
---@param ctx                            era.m.diffview.view.commits.IContext
function M.render_filetree(ctx)
  local lyt = ctx.layout
  local state = ctx.state

  if not lyt.filetree_bufnr or not vim.api.nvim_buf_is_valid(lyt.filetree_bufnr) then
    return
  end

  local current_commit = state:get_current_commit()
  if not current_commit or not current_commit.files then
    -- Clear filetree if no commit selected
    pane_filetree.apply_to_buffer(lyt.filetree_bufnr, {
      lines = {},
      highlights = {},
      line_map = {},
    })
    return
  end

  local collapsed_dirs = state:get_collapsed_dirs()
  local panel_width = config.FILETREE_WIDTH

  if lyt.filetree_winnr and vim.api.nvim_win_is_valid(lyt.filetree_winnr) then
    panel_width = vim.api.nvim_win_get_width(lyt.filetree_winnr)
  end

  local result = pane_filetree.render(current_commit.files, {
    collapsed_dirs = collapsed_dirs,
    panel_width = panel_width,
  })

  pane_filetree.apply_to_buffer(lyt.filetree_bufnr, result)
end

---Open file entry in sbs view
---@async
---@param ctx                            era.m.diffview.view.commits.IContext
---@param commit                         era.m.diffview.ICommit
---@param entry                          era.m.diffview.IFileEntry
---@param token                          ?stl.c.CancellationToken
function M.open_entry(ctx, commit, entry, token)
  local lyt = ctx.layout

  if not lyt.sbs_left_winnr or not vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) then
    return
  end
  if not lyt.sbs_right_winnr or not vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    return
  end
  local is_current = ctx.begin_preview and ctx.begin_preview() or nil ---@type (fun(): boolean)|nil

  pane_sbs.open_commit_entry({
    left_winnr = lyt.sbs_left_winnr,
    right_winnr = lyt.sbs_right_winnr,
    commit = commit,
    entry = entry,
    token = token,
    is_current = is_current,
    get_fold_unchanged = function()
      return ctx.state:get_fold_unchanged()
    end,
  })
  if is_current and not is_current() then
    return
  end
  if not vim.api.nvim_win_is_valid(lyt.sbs_left_winnr) or not vim.api.nvim_win_is_valid(lyt.sbs_right_winnr) then
    return
  end

  local setup_sbs = ctx.setup_sbs ---@type (fun(bufnr: integer): nil)|nil
  if setup_sbs == nil then
    setup_sbs = function(bufnr)
      require("era.m.diffview.view.commits.keymap").setup_sbs(ctx, bufnr)
    end
  end
  setup_sbs(vim.api.nvim_win_get_buf(lyt.sbs_left_winnr))
  setup_sbs(vim.api.nvim_win_get_buf(lyt.sbs_right_winnr))
end

---Clear sbs view
---@param ctx                            era.m.diffview.view.commits.IContext
function M.clear_sbs(ctx)
  local lyt = ctx.layout
  local is_current = ctx.begin_preview and ctx.begin_preview() or nil ---@type (fun(): boolean)|nil

  if
    lyt.sbs_left_winnr
    and vim.api.nvim_win_is_valid(lyt.sbs_left_winnr)
    and lyt.sbs_right_winnr
    and vim.api.nvim_win_is_valid(lyt.sbs_right_winnr)
  then
    pane_sbs.clear(lyt.sbs_left_winnr, lyt.sbs_right_winnr, {
      is_current = is_current,
      get_fold_unchanged = function()
        return ctx.state:get_fold_unchanged()
      end,
    })
  end
end

----------------------------------------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------------------------------------

---@type table<integer, era.m.diffview.view.commits.ILayout>
M.__layouts__ = {}

---Store layout instance
---@param tabnr                          integer
---@param lyt                            era.m.diffview.view.commits.ILayout
function M.set_layout(tabnr, lyt)
  M.__layouts__[tabnr] = lyt
end

---Get layout instance
---@param tabnr                          integer|nil
---@return era.m.diffview.view.commits.ILayout|nil
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
