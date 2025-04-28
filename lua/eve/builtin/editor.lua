---@class eve.builtin.editor
local M = {}

---@return string
function M.get_selected_text()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local filetype = vim.bo[bufnr].filetype ---@type string
  if filetype == eve.filetype.TERM then
    return ""
  end

  local saved_reg = vim.fn.getreg("v")
  vim.cmd([[noautocmd sil norm! "vy]])

  local selected_text = vim.fn.getreg("v")
  vim.fn.setreg("v", saved_reg)
  return selected_text or ""
end

---@return integer
---@return integer
function M.get_visual_lnum_range()
  local lnum_1 = vim.fn.getcurpos()[2] ---@type integer
  local lnum_2 = vim.fn.line("v") ---@type integer
  if lnum_1 < lnum_2 then
    return lnum_1, lnum_2
  end
  return lnum_2, lnum_1
end

---@param filepath                      string|nil
---@return boolean
function M.is_valid_filepath(filepath)
  if filepath == nil or filepath == "" or filepath == eve.setting.BUF_UNTITLED then
    return false
  end
  return eve.path.is_exist_filepath(filepath)
end

---@param winnr_source                  integer|nil
---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(winnr_source, filepath, lnum, col)
  filepath = eve.path.normalize(filepath)

  local winnr = eve.win.pick_sourcefile(winnr_source) ---@type integer|nil
  if winnr == nil then
    return false
  end

  vim.api.nvim_set_current_win(winnr)
  vim.cmd("edit " .. vim.fn.fnameescape(filepath))

  vim.schedule(function()
    vim.cmd.stopinsert()

    if lnum ~= nil and col ~= nil then
      pcall(function()
        vim.api.nvim_win_set_cursor(winnr, { lnum, col })
      end)
    end
  end)
  return true
end

---@param winnr_source                  integer|nil
---@param filepaths                     string[]
---@return nil
function M.open_filepaths(winnr_source, filepaths)
  if #filepaths < 1 then
    return
  end

  ---@type integer|nil
  local winnr = (
    winnr_source ~= nil
    and winnr_source > 0
    and vim.api.nvim_win_is_valid(winnr_source)
    and eve.win.is_sourcefile(winnr_source)
  )
      and winnr_source
    or eve.winpicker.pick_window(eve.win.is_sourcefile, winnr_source, true)

  if winnr == nil then
    return
  end

  vim.api.nvim_set_current_win(winnr)
  for _, filepath in ipairs(filepaths) do
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
  end

  vim.schedule(function()
    vim.cmd.stopinsert()
  end)
end

return M
