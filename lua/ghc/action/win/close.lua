---@class ghc.action.win
local M = require("ghc.action.win.mod")

---@return nil
function M.close_current()
  vim.cmd("close")
end

---@return nil
function M.close_others()
  vim.cmd("only")
end
