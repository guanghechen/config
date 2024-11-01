local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander.register({
  uuid = uuids.find_buffers,
  desc = "find: buffers",
  action = function()
    local cwd = eve.path.cwd() ---@type string
    local workspace = eve.path.workspace() ---@type string

    fml.fn.select_files({
      cwd = cwd,
      title = "Find buffers",
      flag_fuzzy = true,
      flag_regex = false,
      fetch_filepaths = function()
        local filepaths = {} ---@type string[]
        for _, buf in pairs(eve.context.state.bufs) do
          if buf.filename ~= eve.constants.BUF_UNTITLED and eve.path.is_under(workspace, buf.filepath) then
            local relative_filepath = eve.path.relative(cwd, buf.filepath, true) ---@type string
            table.insert(filepaths, relative_filepath)
          end
        end
        return filepaths
      end,
    })
  end,
})
