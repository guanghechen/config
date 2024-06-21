local util_window = require("guanghechen.util.window")

---@class ghc.core.action.window
local M = require("ghc.core.action.window.module")

function M.resize_window_horizontal_minus()
  local step = vim.v.count1 or 1
  vim.cmd("resize -" .. step)
end

function M.resize_window_horizontal_plus()
  local step = vim.v.count1 or 1
  vim.cmd("resize +" .. step)
end

function M.resize_window_vertical_minus()
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize -" .. step)
end

function M.resize_window_vertical_plus()
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize +" .. step)
end

M.split_window_horizontal = "<C-w>s"
M.split_window_vertical = "<C-w>v"

M.swap_window_with_picker = function()
  local winnr_current = vim.api.nvim_get_current_win()
  local winnr_target = util_window.pick_window({ motivation = "swap" })
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
end
