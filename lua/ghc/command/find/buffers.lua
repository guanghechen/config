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
          local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
          local relative_filepath = path.relative(cwd, filepath, true) ---@type string
          table.insert(filepaths, relative_filepath)
        end
        return filepaths
      end,
    })
  end,
})
