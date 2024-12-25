local __module_name__ = "fml.action.refresh" ---@type string

local reporter = require("eve.lib.reporter")
local command = require("eve.lib.command")
local state = require("eve.state")

---@class fml.action.refresh
local M = {}

---@param context                       eve.lib.command.IContext
---@return nil
function M.refresh_all(context)
  local bufnr = context.bufnr ---@type integer
  local devmode = state.flight.devmode:snapshot() ---@type boolean

  vim.cmd.checktime()
  state.refresh()

  pcall(function()
    require("gitsigns").refresh()
  end)

  pcall(function()
    if vim.treesitter then
      local parser = vim.treesitter.get_parser(bufnr)
      if parser ~= nil then
        parser:invalidate()
      end
    end
  end)

  if devmode then
    vim.cmd(command.definitions.ux.reload_theme.uuid .. " force")
  end

  vim.cmd("LspRestart")
  state.status.dirtier_statusline:mark_dirty()
  state.status.dirtier_tabline:mark_dirty()
  vim.cmd.redraw()

  reporter.info({
    from = __module_name__,
    message = "Refreshed all!",
  })
end

return M
