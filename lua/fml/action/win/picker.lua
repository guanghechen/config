---@class fml.action.win.picker
local M = {}

---@return nil
function M.focus()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  local winnr_target = eve.editor.pick_focusable_win(winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    vim.api.nvim_set_current_win(winnr_target)
  end
end

---@return nil
function M.project()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  local winnr_target = eve.editor.pick_projectable_win(winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    local cursor_source = vim.api.nvim_win_get_cursor(winnr_source)
    local bufnr = vim.api.nvim_win_get_buf(winnr_source) ---@type integer

    vim.api.nvim_win_set_buf(winnr_target, bufnr)
    vim.api.nvim_win_set_cursor(winnr_target, cursor_source)
    vim.api.nvim_set_current_win(winnr_target)
  end
end

---@return nil
function M.swap()
  local winnr_source = vim.api.nvim_get_current_win() ---@type integer
  local winnr_target = eve.editor.pick_swappable_win(winnr_source) ---@type integer|nil
  if winnr_target and winnr_target ~= winnr_source then
    local wincfg_source = vim.api.nvim_win_get_config(winnr_source) ---@type vim.api.keyset.win_config
    local wincfg_target = vim.api.nvim_win_get_config(winnr_target) ---@type vim.api.keyset.win_config

    vim.api.nvim_win_set_config(winnr_source, wincfg_target)
    vim.api.nvim_win_set_config(winnr_target, wincfg_source)
  end
end

return M
