---@class fml.action.diagnostic
local M = {}

---@param context                       eve.command.IContext
---@return nil
function M.goto_next(context)
  vim.diagnostic.goto_next({ win_id = context.winnr })
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_next_error(context)
  vim.diagnostic.goto_next({ win_id = context.winnr, severity = vim.diagnostic.severity.ERROR })
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_next_warn(context)
  vim.diagnostic.goto_next({ win_id = context.winnr, severity = vim.diagnostic.severity.WARN })
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_next_hint(context)
  vim.diagnostic.goto_next({ win_id = context.winnr, severity = vim.diagnostic.severity.HINT })
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_next_info(context)
  vim.diagnostic.goto_next({ win_id = context.winnr, severity = vim.diagnostic.severity.INFO })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.goto_next_quickfix(context)
  vim.cmd.cnext()
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_prev(context)
  vim.diagnostic.goto_prev({ win_id = context.winnr })
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_prev_error(context)
  vim.diagnostic.goto_prev({ win_id = context.winnr, severity = vim.diagnostic.severity.ERROR })
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_prev_warn(context)
  vim.diagnostic.goto_prev({ win_id = context.winnr, severity = vim.diagnostic.severity.WARN })
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_prev_hint(context)
  vim.diagnostic.goto_prev({ win_id = context.winnr, severity = vim.diagnostic.severity.HINT })
end

---@param context                       eve.command.IContext
---@return nil
function M.goto_prev_info(context)
  vim.diagnostic.goto_prev({ win_id = context.winnr, severity = vim.diagnostic.severity.INFO })
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.goto_prev_quickfix(context)
  vim.cmd.cprev()
end

---@param context                       eve.command.IContext
---@return nil
---@diagnostic disable-next-line: unused-local
function M.line(context)
  local _, winnr = vim.diagnostic.open_float({
    header = "diagnostic (line)",
    scope = "line",
    focus = true,
    focusable = true,
    border = "rounded",
  })

  local dressing_float_win = require("fml.dressing.floatwin")
  dressing_float_win(winnr, 100)
end

return M
