local functional = require("eve.lib.functional")
local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander.register({
  uuid = uuids.buf_pin,
  desc = "buf: pin",
  action = function()
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local meta_buf = state.buf.resolve(bufnr) ---@type eve.t.state.buf.meta.state|nil
    if meta_buf ~= nil then
      local filepath = meta_buf.filepath ---@type string

      local pinned_list = state.bookmark.pinned:snapshot() ---@type string[]
      local k = functional.find_index(pinned_list, filepath) ---@type integer|nil
      if k == nil then
        table.insert(pinned_list, filepath)
      else
        for i = k + 1, #pinned_list, 1 do
          pinned_list[k] = pinned_list[i]
          k = k + 1
        end
        pinned_list[k] = nil
      end

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
      if meta_tab ~= nil then
        meta_tab:toggle_pin(bufnr)
      end
      state.status.dirtier_tabline:mark_dirty()
    end
  end,
})
