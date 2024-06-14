local guanghechen = require("guanghechen")

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

function M.toggle_document_diagnositics()
  vim.cmd("Trouble diagnostics toggle filter.buf=0")
end

function M.toggle_workspace_diagnostics()
  vim.cmd("Trouble diagnostics toggle")
end

function M.toggle_loclist()
  vim.cmd("Trouble loclist toggle")
end

function M.toggle_quickfix()
  vim.cmd("Trouble qflist toggle")
end

function M.toggle_previous_quickfix_item()
  if require("trouble").is_open() then
    require("trouble").prev({ skip_groups = true, jump = true })
  else
    local ok, err = pcall(vim.cmd.cprev)
    if not ok then
      guanghechen.util.reporter.error({
        from = "vim.cmd.cprev",
        subject = "toggle_previous_quickfix_item",
        details = {
          err = err,
        },
      })
    end
  end
end

function M.toggle_next_quickfix_item()
  if require("trouble").is_open() then
    require("trouble").next({ skip_groups = true, jump = true })
  else
    local ok, err = pcall(vim.cmd.cnext)
    if not ok then
      guanghechen.util.reporter.error({
        from = "vim.cmd.cnext",
        subject = "toggle_next_quickfix_item",
        details = {
          err = err,
        },
      })
    end
  end
end

return M
