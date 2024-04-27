local util = {
  table = require("ghc.util.table"),
}

---@class ghc.action.window
local M = {}

M.focus_window_top = "<C-w>k"
M.focus_window_right = "<C-w>l"
M.focus_window_bottom = "<C-w>j"
M.focus_window_left = "<C-w>h"

M.split_window_horizontal = "<C-w>s"
M.split_window_vertical = "<C-w>v"

M.close_window_current = "<cmd>close<cr>"
M.close_window_others = "<cmd>only<cr>"

---@param opts { allow_explorer: boolean }
M.pick_window = function(opts)
  local allow_explorer = opts.allow_explorer
  return require("window-picker").pick_window({
    filter_rules = {
      autoselect_one = true,
      include_current_win = false,
      bo = {
        filetype = util.table.merge_multiple_array(allow_explorer and {} or { "neo-tree" }, { "neo-tree-popup", "notify" }),
        buftype = { "terminal", "quickfix" },
      },
    },
  })
end

M.focus_window_with_picker = function()
  local win_id_current = vim.api.nvim_get_current_win()
  local win_id_target = M.pick_window({ allow_explorer = true })
  if win_id_target == nil or win_id_current == win_id_target then
    return
  end
  vim.api.nvim_set_current_win(win_id_target)
end

M.swap_window_with_picker = function()
  local win_id_current = vim.api.nvim_get_current_win()
  local win_id_target = M.pick_window({ allow_explorer = false })
  if win_id_target == nil or win_id_current == win_id_target then
    return
  end

  local buf_id_current = vim.api.nvim_win_get_buf(win_id_current)
  local buf_id_target = vim.api.nvim_win_get_buf(win_id_target)

  local cursor_current = vim.api.nvim_win_get_cursor(win_id_current)
  local cursor_target = vim.api.nvim_win_get_cursor(win_id_target)

  vim.api.nvim_win_set_buf(win_id_current, buf_id_target)
  vim.api.nvim_win_set_buf(win_id_target, buf_id_current)
  vim.api.nvim_win_set_cursor(win_id_target, cursor_current)
  vim.api.nvim_win_set_cursor(win_id_current, cursor_target)
  vim.api.nvim_set_current_win(win_id_target)
end

-- Project the buffer on the current window to the selected window
M.project_window_with_picker = function()
  local win_id_current = vim.api.nvim_get_current_win()
  local win_id_target = M.pick_window({ allow_explorer = false })
  if win_id_target == nil or win_id_current == win_id_target then
    return
  end

  local buf_id_current = vim.api.nvim_win_get_buf(win_id_current)

  local cursor_current = vim.api.nvim_win_get_cursor(win_id_current)

  vim.api.nvim_win_set_buf(win_id_target, buf_id_current)
  vim.api.nvim_win_set_cursor(win_id_target, cursor_current)
  vim.api.nvim_set_current_win(win_id_target)
end

return M
