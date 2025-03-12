local __module_name__ = "fml.action.refresh" ---@type string

local reporter = require("eve.builtin.reporter")
local state = require("eve.state")
local command = require("eve.command")

---@class fml.action.refresh
local M = {}

---@return nil
function M.refresh_all()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local bufnr_sourcefile = state.tab.get_bufnr_sourcefile(tabnr) ---@type integer|nil

  local devmode = state.flight.devmode:snapshot() ---@type boolean

  vim.cmd.checktime()
  state.refresh()

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
    require("plenary.reload").reload_module("eve.constant.palette")
    require("plenary.reload").reload_module("eve.constant.theme")
    require("plenary.reload").reload_module("eve.constant.hlgroup")
    vim.cmd(command.definitions.ux.reload_theme.uuid .. " force")
  end

  vim.cmd("LspRestart")
  state.status.suppress_warning:next(true)
  state.status.dirtier_statusline:mark_dirty()
  state.status.dirtier_tabline:mark_dirty()
  vim.cmd.redraw()

  reporter.info({
    from = __module_name__,
    message = "Refreshed all!",
  })
end

return M
