local path = require("eve.lib.path")
local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander.register({
  uuid = uuids.find_pinned_files,
  desc = "find: pinned files",
  action = function()
    local cwd = path.cwd() ---@type string

    fml.fn.select_files({
      cwd = cwd,
      title = "Find pinned files",
      flag_fuzzy = true,
      flag_regex = false,
      fetch_filepaths = function()
        local filepaths = {} ---@type string[]
        local pinned_filepaths = state.state.bookmark.pinned:snapshot() ---@type string[]
        for _, filepath in ipairs(pinned_filepaths) do
          local relative_filepath = path.relative(cwd, filepath, true) ---@type string
          table.insert(filepaths, relative_filepath)
        end
        return filepaths
      end,
    })
  end,
})
