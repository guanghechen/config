---@class ghc.core.action.window
local M = {}

M.focus_window_top = "<cmd>NvimTmuxNavigateUp<cr>"
M.focus_window_right = "<cmd>NvimTmuxNavigateRight<cr>"
M.focus_window_bottom = "<cmd>NvimTmuxNavigateDown<cr>"
M.focus_window_left = "<cmd>NvimTmuxNavigateLeft<cr>"

M.split_window_horizontal = "<C-w>s"
M.split_window_vertical = "<C-w>v"

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

function M.close_window_current()
  vim.cmd("close")
end

function M.close_window_others()
  vim.cmd("only")
end

---@param opts { motivation: "focus" | "swap" | "project" }
---@return number | nil
function M.pick_window(opts)
  local motivation = opts.motivation
  local bo = {}

  if motivation == "focus" then
    bo = {
      filetype = { "notify", "noice", "notify" },
      buftype = {},
    }
  elseif motivation == "swap" then
    bo = {
      filetype = { "neo-tree", "neo-tree-popup", "noice", "notify" },
      buftype = { "terminal", "quickfix" },
    }
  elseif motivation == "project" then
    bo = {
      filetype = { "neo-tree", "neo-tree-popup", "noice", "notify" },
      buftype = { "terminal", "quickfix" },
    }
  end

  return require("window-picker").pick_window({
    show_prompt = false,
    filter_rules = {
      autoselect_one = true,
      include_current_win = false,
      bo = bo,
    },
  })
end

M.focus_window_with_picker = function()
  local winnr_current = vim.api.nvim_get_current_win()
  local winnr_target = M.pick_window({ motivation = "focus" })
  if winnr_target == nil or winnr_current == winnr_target then
    return
  end
  vim.api.nvim_set_current_win(winnr_target)
end

M.swap_window_with_picker = function()
  local winnr_current = vim.api.nvim_get_current_win()
  local winnr_target = M.pick_window({ motivation = "swap" })
  if winnr_target == nil or winnr_current == winnr_target then
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

-- Project the buffer on the current window to the selected window
M.project_window_with_picker = function()
  local winnr_current = vim.api.nvim_get_current_win()
  local winnr_target = M.pick_window({ motivation = "project" })
  if winnr_target == nil or winnr_current == winnr_target then
    return
  end

  local bufnr_current = vim.api.nvim_win_get_buf(winnr_current)
  local cursor_current = vim.api.nvim_win_get_cursor(winnr_current)

  vim.api.nvim_win_set_buf(winnr_target, bufnr_current)
  vim.api.nvim_win_set_cursor(winnr_target, cursor_current)
  vim.api.nvim_set_current_win(winnr_target)
end

return M
