---@class ghc.core.action.window
local M = require("ghc.core.action.window.module")
require("ghc.core.action.window.close")
require("ghc.core.action.window.focus")
require("ghc.core.action.window.history")
require("ghc.core.action.window.resize")

if vim.env.TMUX ~= nil then
  require("ghc.core.action.window.navigate-tmux")
else
  require("ghc.core.action.window.navigate-vim")
end

return M
