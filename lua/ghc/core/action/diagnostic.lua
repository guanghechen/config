---@param next boolean
---@param severity? string
local goto_diagnostic = function(next, severity)
  severity = severity and vim.diagnostic.severity[severity] or nil
  if next then
    vim.diagnostic.goto_next({ severity = severity })
  else
    vim.diagnostic.goto_prev({ severity = severity })
  end
end

---@class ghc.core.action.diagnostic
local M = {}

function M.open_line_diagnostics()
  vim.diagnostic.open_float()
end

function M.goto_prev_diagnostic()
  goto_diagnostic(false)
end

function M.goto_next_diagnostic()
  goto_diagnostic(true)
end

function M.goto_prev_error()
  goto_diagnostic(false, "ERROR")
end

function M.goto_next_error()
  goto_diagnostic(true, "ERROR")
end

function M.goto_prev_warn()
  goto_diagnostic(false, "WARN")
end

function M.goto_next_warn()
  goto_diagnostic(true, "WARN")
end

return M
