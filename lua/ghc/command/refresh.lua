local client = require("ghc.context.client")
local cmd_theme = require("ghc.command.theme")

---@class ghc.command.refresh
local M = {}

---@return nil
function M.refresh_all()
  vim.cmd("checktime")
  fml.api.state.refresh_all()

  vim.cmd("LspRestart")
  vim.cmd("redraw")

  local devmode = client.flight_devmode:snapshot() ---@type boolean
  if devmode then
    cmd_theme.reload_theme({ force = true })
  end

  eve.reporter.info({
    from = "ghc.command.refresh",
    subject = "refresh_all",
    message = "Refreshed all.",
  })
end

return M
