local client = require("ghc.context.client")
local session = require("ghc.context.session")

---@class ghc.command.context
local M = {}

function M.edit_client()
  local filepath = client:get_filepath() ---@type string|nil
  if filepath == nil then
    fml.reporter.error({
      from = "ghc.command.context",
      subject = "edit_client",
      message = "Cannot locate the client context filepath.",
      details = { filepath = filepath }
    })
    return
  end

  vim.cmd("noswapfile tabnew " .. filepath)
  vim.bo.backupcopy = "yes"


  ---! The client session will auto reload when the file content changed.
  -- client:load()
end

function M.edit_session()
  local filepath = session:get_filepath() ---@type string|nil
  if filepath == nil then
    fml.reporter.error({
      from = "ghc.command.context",
      subject = "edit_session",
      message = "Cannot locate the session context filepath.",
      details = { filepath = filepath }
    })
    return
  end

  vim.cmd("noswapfile tabnew " .. filepath)
  vim.bo.backupcopy = "yes"

  ---! Reload the session context manually cause it won't auto reload.
  session:load()
end

return M
