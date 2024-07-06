local state = require("fml.api.state")

---@class fml.api.win
local M = require("fml.api.win.mod")

-- Project the buffer on the current window to the selected window
function M.project_with_picker()
  local winnr_current = vim.api.nvim_get_current_win()
  local winnr_target = M.pick("project")
  if not winnr_target or winnr_current == winnr_target then
    return
  end

  local bufnr_current = vim.api.nvim_win_get_buf(winnr_current)
  local cursor_current = vim.api.nvim_win_get_cursor(winnr_current)

  vim.api.nvim_win_set_buf(winnr_target, bufnr_current)
  vim.api.nvim_win_set_cursor(winnr_target, cursor_current)
  vim.api.nvim_set_current_win(winnr_target)

  local win = state.wins[winnr_target]
  if win ~= nil then
    win.buf_history:push(bufnr_current)
  end
end
