local __module_name__ = "ghc.command.refresh" ---@type string

local reporter = require("eve.lib.reporter")
local commander = require("eve.builtin.commander")
local status = require("eve.builtin.status")
local state = require("eve.state")
local uuids = commander.uuids ---@type eve.builtin.commander.uuids

commander.register({
  uuid = uuids.refresh_all,
  desc = "refresh: all",
  action = function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local devmode = state.state.flight.devmode:snapshot() ---@type boolean

    vim.cmd.checktime()
    fml.fn.refresh_state()

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
      commander.execute(uuids.reload_theme, "force")
    end

    vim.cmd("LspRestart")
    status.statusline_dirtier:mark_dirty()
    status.tabline_dirtier:mark_dirty()
    vim.cmd.redraw()

    reporter.info({
      from = __module_name__,
      message = "Refreshed all!",
    })
  end,
})
