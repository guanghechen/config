---@class fml.action.diagnostic
local M = {}

---@return nil
function M.goto_next()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_next({ win_id = winnr })
end

---@return nil
function M.goto_next_error()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_next({ win_id = winnr, severity = vim.diagnostic.severity.ERROR })
end

---@return nil
function M.goto_next_warn()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_next({ win_id = winnr, severity = vim.diagnostic.severity.WARN })
end

---@return nil
function M.goto_next_hint()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_next({ win_id = winnr, severity = vim.diagnostic.severity.HINT })
end

---@return nil
function M.goto_next_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_next({ win_id = winnr, severity = vim.diagnostic.severity.INFO })
end

---@return nil
function M.goto_next_quickfix()
  vim.cmd.cnext()
end

---@return nil
function M.goto_prev()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_prev({ win_id = winnr })
end

---@return nil
function M.goto_prev_error()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_prev({ win_id = winnr, severity = vim.diagnostic.severity.ERROR })
end

---@return nil
function M.goto_prev_warn()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_prev({ win_id = winnr, severity = vim.diagnostic.severity.WARN })
end

---@return nil
function M.goto_prev_hint()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_prev({ win_id = winnr, severity = vim.diagnostic.severity.HINT })
end

---@return nil
function M.goto_prev_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.goto_prev({ win_id = winnr, severity = vim.diagnostic.severity.INFO })
end

---@return nil
function M.goto_prev_quickfix()
  vim.cmd.cprev()
end

---@return nil
function M.line()
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
