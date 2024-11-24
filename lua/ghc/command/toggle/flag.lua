local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander
  .register({
    uuid = uuids.toggle_dressing_autopairs,
    desc = "toggle: dressing autopairs",
    action = function()
      local observable = eve.context.state.dressing.autopairs ---@type t.eve.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)
      eve.commander.execute(uuids.reload_theme, "force")
    end,
  })
  .register({
    uuid = uuids.toggle_dressing_winsep,
    desc = "toggle: dressing winsep",
    action = function()
      local observable = eve.context.state.dressing.winsep ---@type t.eve.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)
      eve.commander.execute(uuids.reload_theme, "force")
    end,
  })
  .register({
    uuid = uuids.toggle_relativenumber,
    desc = "toggle: relativenumber",
    action = function()
      local observable = eve.context.state.theme.relativenumber ---@type t.eve.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)

      if vim.o.nu then
        vim.opt.relativenumber = not flag
        vim.cmd.redraw()
      end
    end,
  })
  .register({
    uuid = uuids.toggle_theme_mode,
    desc = "toggle: theme mode",
    action = function()
      local theme = eve.context.state.theme.theme:snapshot() ---@type t.eve.e.Theme
      local mode = eve.context.state.theme.mode:snapshot() ---@type t.eve.e.ThemeMode
      local next_mode = mode == "light" and "dark" or "light"
      local scheme_name = theme .. "_" .. next_mode
      eve.commander.execute(uuids.toggle_theme, scheme_name)
    end,
  })
  .register({
    uuid = uuids.toggle_theme_transparency,
    desc = "toggle: theme transparency",
    action = function()
      local observable = eve.context.state.theme.transparency ---@type t.eve.collection.IObservable
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
