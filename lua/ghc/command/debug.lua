local client = require("ghc.context.client")
local session = require("ghc.context.session")
local transient = require("ghc.context.transient")

---@class ghc.command.debug
local M = {}

---@return nil
function M.show_context()
  local context = {
    config = client:get_snapshot(),
    session = session:get_snapshot(),
    transient = transient:get_snapshot(),
  }

  fml.reporter.info({ 
    from = "ghc.command.debug",
    subject = "show_context",
    details = context
  })
end

---@return nil
function M.show_context_all()
  local context = {
    config = vim.tbl_deep_extend("force", { _location = ghc.context.client:get_filepath() }, client:get_snapshot_all()),
    session = vim.tbl_deep_extend("force", { _location = ghc.context.session:get_filepath() }, session:get_snapshot_all()),
    transient = vim.tbl_deep_extend("force", {}, transient:get_snapshot_all()),
  }

  fml.reporter.info({ 
    from = "ghc.command.debug",
    subject = "show_context_all",
    details = context
  })
end

return M
