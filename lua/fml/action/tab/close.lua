local __module_name__ = "fml.action.tab" ---@type string

local reporter = require("eve.builtin.reporter")
local state = require("eve.state")

---@class fml.action.tab
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.close(context)
  local N = vim.fn.tabpagenr("$") ---@type integer
  if N <= 1 then
    reporter.warn({
      from = __module_name__,
      subject = "close",
      message = "This is the last tab, cannot close it.",
    })
    return
  end
  vim.cmd.tabclose()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.close_to_leftest(context)
  local tabid = vim.fn.tabpagenr() ---@type integer
  for _ = 1, tabid - 1, 1 do
    vim.cmd("-tabclose")
  end
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.close_to_rightest(context)
  local N = vim.fn.tabpagenr("$") ---@type integer
  local tabid = vim.fn.tabpagenr() ---@type integer
  for _ = tabid + 1, N, 1 do
    vim.cmd("+tabclose")
  end
end

---@param context                       eve.command.IContext
---@return nil
function M.close_others(context)
  local tabnr = context.tabnr ---@type integer
  vim.cmd("tabonly")
  state.tab.tab_history:clear()
  state.tab.tab_history:push(tabnr)
end

return M
