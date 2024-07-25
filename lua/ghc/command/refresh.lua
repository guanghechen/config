---@class ghc.command.refresh
local M = {}

---@return nil
function M.refresh_all()
  vim.cmd("checktime")
  vim.cmd("redraw")
  fml.reporter.info({
    from = "ghc.command.refresh",
    subject = "refresh_all",
    message = "Refreshed all.",
  })
end

return M
