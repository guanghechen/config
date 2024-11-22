local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander.register({
  uuid = uuids.outline_toggle,
  desc = "code: toggle outline",
  action = function()
    require("aerial").toggle()
  end,
})
