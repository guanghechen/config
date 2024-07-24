---@class ghc.command.refresh
local M = {}

---@return nil
function M.refresh_all()
  vim.cmd("checktime")
  vim.cmd("redraw")
end

return M
