---@class ghc.action.win
local M = require("ghc.action.win.mod")

---! Project the buffer on the current window to the selected window
---@return nil
function M.project_with_picker()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local winnr_target = M.pick("project") ---@type integer|nil
  if not winnr_target or winnr_cur == winnr_target then
    return
  end

  local bufnr_cur = vim.api.nvim_win_get_buf(winnr_cur) ---@type integer
  local cursor_current = vim.api.nvim_win_get_cursor(winnr_cur)

  vim.api.nvim_win_set_buf(winnr_target, bufnr_cur)
  vim.api.nvim_win_set_cursor(winnr_target, cursor_current)
  vim.api.nvim_set_current_win(winnr_target)
end

return M
