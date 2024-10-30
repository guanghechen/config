local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander
  .register({
    uuid = uuids.win_close,
    desc = "win: close current",
    action = function()
      vim.cmd.close()
    end,
  })
  .register({
    uuid = uuids.win_close_others,
    desc = "win: close others",
    action = function()
      vim.cmd.only()
    end,
  })
