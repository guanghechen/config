---@class fml.action.lsp
local M = {}

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.rename(context)
  vim.lsp.buf.rename()
  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.show_code_action(context)
  vim.lsp.buf.code_action()
  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.show_code_action_source(context)
  vim.lsp.buf.code_action({
    context = {
      only = { "source" },
      diagnostics = {},
    },
  })
  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
end

return M
