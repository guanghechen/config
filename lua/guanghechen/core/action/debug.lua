---@class guanghechen.core.action.debug
local M = {}

function M.show_context()
  local context = {
    config = ghc.context.client:get_snapshot(),
    session = ghc.context.session:get_snapshot(),
    transient = ghc.context.transient:get_snapshot(),
  }
  fml.reporter.info({ from = "show_context", details = context })
end

function M.show_context_all()
  local context = {
    config = vim.tbl_deep_extend("force", { _location = ghc.context.client:get_filepath() }, ghc.context.client:get_snapshot_all()),
    session = vim.tbl_deep_extend("force", { _location = ghc.context.session:get_filepath() }, ghc.context.session:get_snapshot_all()),
    transient = vim.tbl_deep_extend("force", {}, ghc.context.transient:get_snapshot_all()),
  }
  fml.reporter.info({ from = "show_context_all", details = context })
end

return M
