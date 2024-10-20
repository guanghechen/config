local cmd_theme = require("ghc.action.theme")

---@class ghc.action.refresh
local M = {}

---@return nil
function M.refresh_all()
  vim.cmd("checktime")
  fml.fn.refresh_state()

  vim.cmd("LspRestart")
  vim.cmd.redraw()

  local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean
  if devmode then
    cmd_theme.reload_theme({ force = true })
  end

  eve.reporter.info({
    from = "ghc.action.refresh",
    subject = "refresh_all",
    message = "Refreshed all.",
  })
end

return M
