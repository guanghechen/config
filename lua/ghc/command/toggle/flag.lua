local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.toggle_dressing_autopairs,
    desc = "toggle: dressing autopairs",
    action = function()
      local observable = eve.context.state.dressing.autopairs ---@type eve.t.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)
      eve.commander.execute(uuids.reload_theme, "force")
    end,
  })
  .register({
    uuid = uuids.toggle_dressing_winsep,
    desc = "toggle: dressing winsep",
    action = function()
      local observable = eve.context.state.dressing.winsep ---@type eve.t.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)
      eve.commander.execute(uuids.reload_theme, "force")
    end,
  })
  .register({
    uuid = uuids.toggle_relativenumber,
    desc = "toggle: relativenumber",
    action = function()
      local observable = eve.context.state.theme.relativenumber ---@type eve.t.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)

      if vim.o.nu then
        vim.opt.relativenumber = not flag
        vim.cmd.redraw()
      end
    end,
  })
  .register({
    uuid = uuids.toggle_theme_transparency,
    desc = "toggle: theme transparency",
    action = function()
      local observable = eve.context.state.theme.transparency ---@type eve.t.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)
      eve.commander.execute(uuids.reload_theme, "force")
    end,
  })
  .register({
    uuid = uuids.toggle_wrap,
    desc = "toggle: wrap (temporary)",
    action = function()
      ---@diagnostic disable-next-line: undefined-field
      local wrap = vim.opt_local.wrap:get() ---@type boolean
      vim.opt_local.wrap = not wrap
    end,
  })
