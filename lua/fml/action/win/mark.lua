---@class fml.action.win
local M = {}

---@return nil
function M.mark_sourcefile()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  eve.win.set_type(winnr, nil)

  vim.wo[winnr].cursorline = true
  vim.wo[winnr].number = true
  vim.wo[winnr].relativenumber = true
  vim.wo[winnr].signcolumn = "yes"
  vim.wo[winnr].spell = false
  vim.wo[winnr].winfixbuf = false
  vim.wo[winnr].wrap = false
end

return M
