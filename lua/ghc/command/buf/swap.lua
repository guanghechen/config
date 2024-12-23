local functional = require("eve.lib.functional")
local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.buf_swap_left,
    desc = "buf: swap left",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
      if meta_tab == nil then
        return
      end

      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local buf_cur, bufid_cur = meta_tab:find_buf(bufnr_cur)
      if buf_cur == nil or bufid_cur == nil then
        return
      end

      local step = math.max(1, vim.v.count1 or 1) ---@type integer
      local bufid_next = functional.navigate_circular(bufid_cur, -step, #meta_tab.bufs) ---@type integer
      if bufid_cur == bufid_next then
        return
      end

      local buf_next = meta_tab.bufs[bufid_next] ---@type eve.t.state.tab.buf.state

      ---! Don't swap the two buffers if their's pinned status not equal.
      if buf_cur.pinned ~= buf_next.pinned then
        return
      end

      meta_tab.bufs[bufid_next] = buf_cur
      meta_tab.bufs[bufid_cur] = buf_next
      state.status.dirtier_statusline:mark_dirty()
      state.status.dirtier_tabline:mark_dirty()
    end,
  })
  .register({
    uuid = uuids.buf_swap_right,
    desc = "buf: swap right",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta_tab = state.tab.resolve(tabnr) ---@type eve.state.tab.meta.state|nil
      if meta_tab == nil then
        return
      end

      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local buf_cur, bufid_cur = meta_tab:find_buf(bufnr_cur)
      if buf_cur == nil or bufid_cur == nil then
        return
      end

      local step = math.max(1, vim.v.count1 or 1) ---@type integer
      local bufid_next = functional.navigate_circular(bufid_cur, step, #meta_tab.bufs) ---@type integer
      if bufid_cur == bufid_next then
        return
      end

      local buf_next = meta_tab.bufs[bufid_next] ---@type eve.t.state.tab.buf.state

      ---! Don't swap the two buffers if their's pinned status not equal.
      if buf_cur.pinned ~= buf_next.pinned then
        return
      end

      meta_tab.bufs[bufid_next] = buf_cur
      meta_tab.bufs[bufid_cur] = buf_next
      state.status.dirtier_statusline:mark_dirty()
      state.status.dirtier_tabline:mark_dirty()
    end,
  })
