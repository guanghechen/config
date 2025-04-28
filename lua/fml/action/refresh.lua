local __module_name__ = "fml.action.refresh" ---@type string

---@class fml.action.refresh
local M = {}

---@return nil
function M.refresh_all()
  local bufnr_sourcefile = eve.status.get_bufnr_sourcefile() ---@type integer|nil
  local devmode = eve.state.flight.devmode:snapshot() ---@type boolean

  vim.cmd.checktime()
  eve.state.refresh()

  pcall(function()
    require("gitsigns").refresh()
  end)

  pcall(function()
    if vim.treesitter and bufnr_sourcefile ~= nil then
      local parser = vim.treesitter.get_parser(bufnr_sourcefile)
      if parser ~= nil then
        parser:invalidate()
      end
    end
  end)

  if devmode then
    require("plenary.reload").reload_module("eve.constant.lang")
    require("plenary.reload").reload_module("eve.constant.theme")
    require("plenary.reload").reload_module("eve.constant.hlgroup")
    vim.cmd(eve.command.definitions.ux.reload_theme.uuid .. " force")
  end

  pcall(vim.cmd.LspRestart)
  eve.status.suppress_warning:next(true)
  eve.status.dirtier_statusline:mark_dirty()
  eve.status.dirtier_tabline:mark_dirty()
  vim.cmd("redraw!")

  eve.reporter.info({
    from = __module_name__,
    message = "Refreshed all!",
  })
end

return M
