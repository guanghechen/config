---@class fml.action.win
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.close(context)
  vim.cmd.close()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.close_others(context)
  vim.cmd.only()
end

return M
