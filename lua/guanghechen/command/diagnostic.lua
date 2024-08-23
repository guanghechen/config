---@param next boolean
---@param severity? string
local goto_diagnostic = function(next, severity)
  local sev = severity and vim.diagnostic.severity[severity] or nil
  if next then
    vim.diagnostic.goto_next({ severity = sev })
  else
    vim.diagnostic.goto_prev({ severity = sev })
  end
end

---@class guanghechen.command.diagnostic
local M = {}

---@return nil
function M.open_line_diagnostics()
  vim.diagnostic.open_float()
end

---@return nil
function M.goto_prev_diagnostic()
  goto_diagnostic(false)
end

---@return nil
function M.goto_next_diagnostic()
  goto_diagnostic(true)
end

---@return nil
function M.goto_prev_error()
  goto_diagnostic(false, "ERROR")
end

---@return nil
function M.goto_next_error()
  goto_diagnostic(true, "ERROR")
end

---@return nil
function M.goto_prev_warn()
  goto_diagnostic(false, "WARN")
end

---@return nil
function M.goto_next_warn()
  goto_diagnostic(true, "WARN")
end

---@return nil
function M.toggle_document_diagnositics()
  vim.cmd("Trouble diagnostics toggle filter.buf=0")
end

---@return nil
function M.toggle_workspace_diagnostics()
  vim.cmd("Trouble diagnostics toggle")
end

---@return nil
function M.toggle_loclist()
  vim.cmd("Trouble loclist toggle")
end

---@return nil
function M.toggle_quickfix()
  vim.cmd("Trouble qflist toggle")
end

---@return nil
function M.toggle_previous_quickfix_item()
  vim.cmd.cprev()
end

---@return nil
function M.toggle_next_quickfix_item()
  vim.cmd.cnext()
end

return M
