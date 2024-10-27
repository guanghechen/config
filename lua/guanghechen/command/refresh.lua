local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander.register({
  uuid = uuids.refresh_all,
  desc = "refresh: all",
  action = function()
    vim.cmd.checktime()
    fml.fn.refresh_state()

    vim.cmd("LspRestart")
    vim.cmd.redraw()

    local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean
    if devmode then
      ghc.action.theme.reload_theme({ force = true })
    end

    eve.reporter.info({
      from = "guanghechen.command.refresh",
      message = "Refreshed all!",
    })
  end,
})
