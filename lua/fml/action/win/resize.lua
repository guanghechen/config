---@class fml.action.win
local M = {}

---@param context                       eve.lib.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.resize_horizontal_minus(context)
  local step = vim.v.count1 or 1
  vim.cmd("resize -" .. step)
end

---@param context                       eve.lib.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.resize_horizontal_plus(context)
  local step = vim.v.count1 or 1
  vim.cmd("resize +" .. step)
end

---@param context                       eve.lib.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.resize_vertical_minus(context)
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize -" .. step)
end

---@param context                       eve.lib.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.resize_vertical_plus(context)
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize +" .. step)
end

return M
