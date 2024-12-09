local path = require("eve.lib.path")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.git_diffview,
    desc = "git: open diffview",
    action = function()
      local diffview = require("diffview") ---@type any
      diffview.open()
    end,
  })
  .register({
    uuid = uuids.git_file_history,
    desc = "git: open file history",
    action = function()
      local diffview = require("diffview") ---@type any
      local filepath = path.current_filepath()
      diffview.file_history(nil, filepath)
    end,
  })
  .register({
    uuid = uuids.git_history,
    desc = "git: open history",
    action = function()
      local diffview = require("diffview") ---@type any
      diffview.file_history()
    end,
  })
