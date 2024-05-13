---@class ghc.core.action.debug
local M = {}

function M.show_context()
  local context = {
    repo = require("ghc.core.context.repo"):get_snapshot(),
  }
  vim.notify("context:" .. vim.inspect(context))
end

function M.show_context_all()
  local context = {
    repo = require("ghc.core.context.repo"):get_snapshot_all(),
  }
  vim.notify("context:" .. vim.inspect(context))
end

return M
