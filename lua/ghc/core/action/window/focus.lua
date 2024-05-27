---@class ghc.core.action.window
local M = require("ghc.core.action.window.module")

local navigate
if vim.env.TMUX ~= nil then
  navigate = require("ghc.core.action.window.navigate-tmux")
else
  navigate = require("ghc.core.action.window.navigate-vim")
end

function M.focus_window_top()
  navigate("k")
end

function M.focus_window_right()
  navigate("l")
end

function M.focus_window_bottom()
  navigate("j")
end
-- lua functions
function M.focus_window_left()
  navigate("h")
end

function M.focus_window_prev()
  navigate("p")
end

function M.focus_window_next()
  navigate("n")
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
