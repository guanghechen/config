local path = require("eve.lib.path")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander.register({
  uuid = uuids.find_buffers,
  desc = "find: buffers",
  action = function()
    local cwd = path.cwd() ---@type string
    fml.fn.select_files({
      cwd = cwd,
      title = "Find buffers",
      flag_fuzzy = true,
      flag_regex = false,
      fetch_filepaths = function()
        local filepaths = {} ---@type string[]
        local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
        for _, bufnr in ipairs(bufnrs) do
          local meta = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
          if meta ~= nil then
            local relative_filepath = path.relative(cwd, meta.filepath, true) ---@type string
            table.insert(filepaths, relative_filepath)
          end
        end
        return filepaths
      end,
    })
  end,
})
