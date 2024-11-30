local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.win_focus_top,
    desc = "win: focus top",
    action = function()
      eve.fn.navigate("k")
    end,
  })
  .register({
    uuid = uuids.win_focus_right,
    desc = "win: focus right",
    action = function()
      eve.fn.navigate("l")
    end,
  })
  .register({
    uuid = uuids.win_focus_bottom,
    desc = "win: focus bottom",
    action = function()
      eve.fn.navigate("j")
    end,
  })
  .register({
    uuid = uuids.win_focus_left,
    desc = "win: focus left",
    action = function()
      eve.fn.navigate("h")
    end,
  })
  .register({
    uuid = uuids.win_focus_prev,
    desc = "win: focus prev",
    action = function()
      eve.fn.navigate("p")
    end,
  })
  .register({
    uuid = uuids.win_focus_next,
    desc = "win: focus next",
    action = function()
      eve.fn.navigate("n")
    end,
  })
