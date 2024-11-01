local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

local runners = {
  [".lua"] = require("ghc.command.run.lua"),
}

eve.commander.register({
  uuid = uuids.run,
  desc = "run: run codes",
  action = function()
    local filepath = eve.path.current_filepath()
    local extname = eve.path.extname(filepath)

    local runner = runners[extname]
    if runner ~= nil then
      runner.run(filepath)
      return
    end
  end,
})
