---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.window" ---@type string

local S = era.m.diffview

---@class era.m.diffview.window
local M = {}

----------------------------------------------------------------------------------------------------
-- winhighlight string generation
----------------------------------------------------------------------------------------------------

---Generate winhighlight string for panel windows
---@param panel_type                   stl.m.diffview.PanelTypeEnum
---@return string
local function gen_winhl(panel_type)
  local parts = {
    "CursorLine:m_dv_cursorline",
    "EndOfBuffer:m_dv_eob",
    "FoldColumn:m_dv_normal",
    "Normal:m_dv_normal",
    "SignColumn:m_dv_normal",
    "WinSeparator:m_dv_winsep",
  }

  if panel_type == "sbs_left" then
    vim.list_extend(parts, {
      "DiffAdd:m_dv_del",
      "DiffChange:m_dv_del",
      "DiffDelete:m_dv_del_dim",
      "DiffText:m_dv_del_inline",
    })
  elseif panel_type == "sbs_right" then
    vim.list_extend(parts, {
      "DiffAdd:m_dv_add",
      "DiffChange:m_dv_add",
      "DiffDelete:m_dv_add_dim",
      "DiffText:m_dv_add_inline",
    })
  end

  return table.concat(parts, ",")
end

----------------------------------------------------------------------------------------------------
-- Window option store (for save/restore)
----------------------------------------------------------------------------------------------------

---@type table<integer, table<string, any>>
M.winopts_store = {}

----------------------------------------------------------------------------------------------------
-- Window option save/restore
----------------------------------------------------------------------------------------------------

---Save window options for later restoration
---@param bufnr                        integer
---@param winnr                        integer
function M.save_winopts(bufnr, winnr)
  if M.winopts_store[bufnr] then
    return
  end

  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  M.winopts_store[bufnr] = {}
  for _, opt in ipairs(S.config.TRACKED_WINOPTS) do
    M.winopts_store[bufnr][opt] = vim.api.nvim_get_option_value(opt, { win = winnr, scope = "local" })
  end

  -- Clean up store entry when buffer is wiped out to prevent memory leak
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      M.winopts_store[bufnr] = nil
    end,
  })
end

---Restore saved window options
---@param bufnr                        integer
function M.restore_winopts(bufnr)
  local saved = M.winopts_store[bufnr]
  if not saved then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    M.winopts_store[bufnr] = nil
    return
  end

  -- Find a window displaying this buffer, or create a temp one
  local wins = vim.fn.win_findbuf(bufnr)
  local winnr = wins[1]

  if winnr then
    for opt, val in pairs(saved) do
      pcall(function()
        vim.api.nvim_set_option_value(opt, val, { win = winnr, scope = "local" })
      end)
    end
  end

  M.winopts_store[bufnr] = nil
end

---Clear saved window options for a buffer
---@param bufnr                        integer
function M.clear_winopts(bufnr)
  M.winopts_store[bufnr] = nil
end

----------------------------------------------------------------------------------------------------
-- Window option application
----------------------------------------------------------------------------------------------------

---Apply panel window options
---@param winnr                        integer
---@param winhl                        string
function M.apply_panel_winopts(winnr, winhl)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  for opt, val in pairs(S.config.WINOPTS_PANEL) do
    vim.api.nvim_set_option_value(opt, val, { win = winnr, scope = "local" })
  end
  vim.api.nvim_set_option_value("winhighlight", winhl, { win = winnr, scope = "local" })
end

---Apply side-by-side window options
---@param winnr                        integer
---@param panel_type                   "sbs_left"|"sbs_right"
function M.apply_sbs_winopts(winnr, panel_type)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local opts = S.config.WINOPTS_SBS
  ---@diagnostic disable-next-line: spell-check
  vim.api.nvim_set_option_value("cursorbind", opts.cursorbind, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("diff", opts.diff, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldenable", opts.foldenable, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldcolumn", opts.foldcolumn, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("foldmethod", opts.foldmethod, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("scrollbind", opts.scrollbind, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", gen_winhl(panel_type), { win = winnr, scope = "local" })
  local foldlevel = dot.context.diffview.flag_fold_unchanges:snapshot() and opts.foldlevel or 99 ---@type integer
  local current = vim.api.nvim_get_option_value("foldlevel", { win = winnr, scope = "local" }) ---@type integer
  if current == foldlevel then
    return
  end

  vim.api.nvim_set_option_value("foldlevel", foldlevel, { win = winnr, scope = "local" })
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(winnr) then
      return
    end
    if foldlevel <= 0 then
      pcall(function() vim.cmd("silent! normal! zM") end)
      return
    end
    pcall(function() vim.cmd("silent! normal! zR") end)
  end)
end

----------------------------------------------------------------------------------------------------
-- Diff mode control
----------------------------------------------------------------------------------------------------

---Turn off diff mode for windows in current tab only
---@diagnostic disable-next-line: spell-check
function M.diff_off_all()
  local tabnr = vim.api.nvim_get_current_tabpage()
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr)

  for _, winnr in ipairs(winnrs) do
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_set_option_value("diff", false, { win = winnr, scope = "local" })
    end
  end
end

---Sync scroll for side-by-side windows
---@param left_winnr                   integer
---@param right_winnr                  integer
function M.sync_scroll(left_winnr, right_winnr)
  if not vim.api.nvim_win_is_valid(left_winnr) or not vim.api.nvim_win_is_valid(right_winnr) then
    return
  end

  -- Trigger scrollbind sync
  vim.api.nvim_win_call(left_winnr, function()
    vim.cmd("normal! \14\25") -- <C-e><C-y>
  end)
end

----------------------------------------------------------------------------------------------------
-- Window helpers
----------------------------------------------------------------------------------------------------

---Check if window is valid
---@param winnr                        integer|nil
---@return boolean
function M.is_valid(winnr)
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
end

---Focus window
---@param winnr                        integer
function M.focus(winnr)
  if M.is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
  end
end

---Close window safely
---@param winnr                        integer|nil
function M.close(winnr)
  if M.is_valid(winnr) then
    pcall(vim.api.nvim_win_close, winnr, true)
  end
end

---Get buffer in window
---@param winnr                        integer
---@return integer|nil
function M.get_buf(winnr)
  if not M.is_valid(winnr) then
    return nil
  end
  return vim.api.nvim_win_get_buf(winnr)
end

---Set buffer in window
---@param winnr                        integer
---@param bufnr                        integer
function M.set_buf(winnr, bufnr)
  if M.is_valid(winnr) and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
end

return M
