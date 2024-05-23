---@class ghc.core.action.window
local M = require("ghc.core.action.window.module")

function M.close_window_current()
  vim.cmd("close")
end

function M.close_window_others()
  vim.cmd("only")
end
