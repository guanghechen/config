---@class ghc.core.action.debug
local M = {}

function M.show_context()
  local context = {
    config = require("ghc.core.context.config"):get_snapshot(),
    session = require("ghc.core.context.session"):get_snapshot(),
  }
  vim.notify("context:" .. vim.inspect(context))
end

function M.show_context_all()
  local context = {
    config = require("ghc.core.context.config"):get_snapshot_all(),
    session = require("ghc.core.context.session"):get_snapshot_all(),
  }
  vim.notify("context:" .. vim.inspect(context))
end

return M
