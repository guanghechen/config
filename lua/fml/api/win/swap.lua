local state = require("fml.api.state")

---@class fml.api.win
local M = require("fml.api.win.mod")

function M.swap_with_picker()
  local winnr_current = vim.api.nvim_get_current_win()
  local winnr_target = M.pick("swap")
  if not winnr_target or winnr_current == winnr_target then
    return
  end

  local bufnr_current = vim.api.nvim_win_get_buf(winnr_current)
  local cursor_current = vim.api.nvim_win_get_cursor(winnr_current)

  local bufnr_target = vim.api.nvim_win_get_buf(winnr_target)
  local cursor_target = vim.api.nvim_win_get_cursor(winnr_target)

  vim.api.nvim_win_set_buf(winnr_current, bufnr_target)
  vim.api.nvim_win_set_buf(winnr_target, bufnr_current)
  vim.api.nvim_win_set_cursor(winnr_target, cursor_current)
  vim.api.nvim_win_set_cursor(winnr_current, cursor_target)
  vim.api.nvim_set_current_win(winnr_target)

  local win_current = state.wins[winnr_current] ---@type fml.api.state.IWinItem|nil
  local win_target = state.wins[winnr_target] ---@type fml.api.state.IWinItem|nil
  if win_current ~= nil and win_target ~= nil then
    state.wins[winnr_current] = win_target
    state.wins[winnr_target] = win_current
  end
end
