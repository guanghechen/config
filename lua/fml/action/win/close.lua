---@class fml.action.win
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.close(context)
  vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
  vim.cmd.close()
end

---@param context                       eve.command.IContext
---@return nil
function M.close_others(context)
  vim.api.nvim_tabpage_set_win(context.tabnr, context.winnr)
  vim.cmd.only()
end

return M
