local __module_name__ = "ghc.action.refresh" ---@type string

local reporter = require("eve.lib.reporter")
local command = require("eve.builtin.command")
local state = require("eve.state")

---@class ghc.action.refresh
local M = {}

---@return nil
function M.refresh_all()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local devmode = state.flight.devmode:snapshot() ---@type boolean

  vim.cmd.checktime()
  eve.fn.refresh_state()

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
    command.execute(command.definitions.ux.reload_theme.uuid, "force")
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
