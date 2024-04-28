---@class ghc.core.action.quit
local M = {}

function M.quit_all()
  vim.cmd("qa")
end

return M
