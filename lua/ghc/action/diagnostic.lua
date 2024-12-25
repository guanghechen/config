---@class ghc.action.diagnostic
local M = {}

---@return nil
function M.goto_next()
  vim.diagnostic.goto_next()
end

---@return nil
function M.goto_next_error()
  vim.diagnostic.goto_next({ sererity = vim.diagnostic.severity.ERROR })
end

---@return nil
function M.goto_next_warn()
  vim.diagnostic.goto_next({ sererity = vim.diagnostic.severity.WARN })
end

---@return nil
function M.goto_next_hint()
  vim.diagnostic.goto_next({ sererity = vim.diagnostic.severity.HINT })
end

---@return nil
function M.goto_next_quickfix()
  vim.cmd.cnext()
end

---@return nil
function M.goto_prev()
  vim.diagnostic.goto_prev()
end

---@return nil
function M.goto_prev_error()
  vim.diagnostic.goto_prev({ sererity = vim.diagnostic.severity.ERROR })
end

---@return nil
function M.goto_prev_warn()
  vim.diagnostic.goto_prev({ sererity = vim.diagnostic.severity.WARN })
end

---@return nil
function M.goto_prev_hint()
  vim.diagnostic.goto_prev({ sererity = vim.diagnostic.severity.HINT })
end

---@return nil
function M.goto_prev_quickfix()
  vim.cmd.cprev()
end

---@return nil
function M.line()
  local dressing_float_win = require("eve.lib.nvim").dressing_float_win

  local _, winnr = vim.diagnostic.open_float({
    header = "diagnostic (line)",
    scope = "line",
    focus = true,
    focusable = true,
    border = "rounded",
  })
  dressing_float_win(winnr, 100)
end

return M
