local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander.register({
  uuid = uuids.refresh_all,
  desc = "refresh: all",
  action = function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean

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

    vim.schedule(function()
      if devmode then
        eve.commander.execute(eve.commander.uuids.reload_theme, "force")
      end
      vim.cmd("LspRestart")
      vim.cmd.redraw()
    end)

    eve.reporter.info({
      from = "ghc.command.refresh",
      message = "Refreshed all!",
    })
  end,
})
