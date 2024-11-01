local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander.register({
  uuid = uuids.notification_dismiss_all,
  desc = "notification: dismiss all",
  action = function()
    require("notify").dismiss({
      silent = true,
      pending = true,
    })
  end,
})
