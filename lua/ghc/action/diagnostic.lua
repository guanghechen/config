---@class ghc.action.diagnostic
local M = {}

---@return nil
function M.toggle_diagnositics_cur()
  vim.cmd("Trouble diagnostics toggle filter.buf=0")
end

---@return nil
function M.toggle_diagnostics()
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

return M
