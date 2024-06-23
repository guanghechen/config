local context_config = require("ghc.core.context.config")
local context_session = require("ghc.core.context.session")

---@class ghc.core.action.debug
local M = {}

function M.show_context()
  local context = {
    config = context_config:get_snapshot(),
    session = context_session:get_snapshot(),
  }
  fml.reporter.info({ from = "show_context", details = context })
end

function M.show_context_all()
  local context = {
    config = vim.tbl_deep_extend("force", { _location = context_config:get_filepath() }, context_config:get_snapshot_all()),
    session = vim.tbl_deep_extend("force", { _location = context_session:get_filepath() }, context_session:get_snapshot_all()),
  }
  fml.reporter.info({ from = "show_context_all", details = context })
end

return M
