local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander.register({
  uuid = uuids.resume,
  desc = "resume: resule last widget or find files",
  action = function()
    if not eve.widgets.resume() then
      eve.commander.execute(eve.commander.uuids.find_files)
    end
  end,
})
