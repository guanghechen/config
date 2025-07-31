---@class fml.action.diagnostic
local M = {}

---@return nil
function M.goto_next()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_error()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.ERROR, win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_warn()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.WARN, win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_hint()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.HINT, win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.INFO, win_id = winnr, count = 1 })
end

---@return nil
function M.goto_next_quickfix()
  vim.cmd.cnext()
end

---@return nil
function M.goto_prev()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_error()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.ERROR, win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_warn()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.WARN, win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_hint()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.HINT, win_id = winnr, count = -1 })
end

---@return nil
function M.goto_prev_info()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  vim.diagnostic.jump({ severity = vim.diagnostic.severity.INFO, win_id = winnr, count = -1 })
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
    source = true,
  })

  vim.schedule(function()
    if winnr ~= nil and eve.win.is_valid(winnr) then
      vim.api.nvim_set_current_win(winnr)
    end
  end)
end

return M
