local state = require("eve.state")

local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.toggle_dressing_hi_pairs,
    desc = "toggle: dressing hi_pairs",
    action = function()
      local observable = state.state.dressing.hi_pairs ---@type eve.lib.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)
      eve.commander.execute(uuids.reload_theme, "force")
    end,
  })
  .register({
    uuid = uuids.toggle_dressing_winsep,
    desc = "toggle: dressing winsep",
    action = function()
      local observable = state.state.dressing.winsep ---@type eve.lib.collection.IObservable
      local flag = observable:snapshot() ---@type boolean
      observable:next(not flag)
      eve.commander.execute(uuids.reload_theme, "force")
    end,
  })
  .register({
    uuid = uuids.toggle_relativenumber,
    desc = "toggle: relativenumber",
    action = function()
      local observable = state.state.theme.relativenumber ---@type eve.lib.collection.IObservable
      local flag = observable:snapshot() ---@type boolean

      vim.opt.relativenumber = not flag
      observable:next(not flag)
    end,
  })
  .register({
    uuid = uuids.toggle_theme_transparency,
    desc = "toggle: theme transparency",
    action = function()
      local observable = state.state.theme.transparency ---@type eve.lib.collection.IObservable
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
