---@class ghc.command.refresh
local M = {}

---@return nil
function M.refresh_all()
  vim.cmd("checktime")
  fml.api.state.refresh_all()

  vim.cmd("LspRestart")
  vim.cmd("redraw")

  eve.reporter.info({
    from = "ghc.command.refresh",
    subject = "refresh_all",
    message = "Refreshed all.",
  })
end

return M
