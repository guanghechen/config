---@class fml.api.win
local M = require("fml.api.win.mod")

---@return nil
function M.close_current()
  vim.cmd("close")
end

---@return nil
function M.close_others()
  vim.cmd("only")
end
