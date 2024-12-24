---@class ghc.action.win
local M = {}

---@return nil
function M.close()
  vim.cmd.close()
end

---@return nil
function M.close_others()
  vim.cmd.only()
end

return M
