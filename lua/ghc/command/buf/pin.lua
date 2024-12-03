local status = require("eve.builtin.status")
local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander.register({
  uuid = uuids.buf_pin,
  desc = "buf: pin",
  action = function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local meta = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
    if meta ~= nil then
      local pinned = meta.pinned ---@type boolean
      local filepath = meta.filepath ---@type string

      local pinned_list = state.state.bookmark.pinned:snapshot() ---@type string[]
      local k = eve.util.find_index(pinned_list, filepath) ---@type integer|nil
      if k == nil then
        table.insert(pinned_list, filepath)
      else
        for i = k + 1, #pinned_list, 1 do
          pinned_list[k] = pinned_list[i]
          k = k + 1
        end
        pinned_list[k] = nil
      end

      meta.pinned = not pinned
      status.tabline_dirtier:mark_dirty()
    end
  end,
})
