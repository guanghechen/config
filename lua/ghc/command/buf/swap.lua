local status = require("eve.builtin.status")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.buf_swap_left,
    desc = "buf: swap left",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta_tab = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if meta_tab == nil then
        return
      end

      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local buf_cur, bufid_cur = meta_tab:find_buf(bufnr_cur)
      if buf_cur == nil or bufid_cur == nil then
        return
      end

      local step = math.max(1, vim.v.count1 or 1) ---@type integer
      local bufid_next = eve.util.navigate_circular(bufid_cur, -step, #meta_tab.bufs) ---@type integer
      if bufid_cur == bufid_next then
        return
      end

      local buf_next = meta_tab.bufs[bufid_next] ---@type eve.t.state.state.tab.meta.IBuf

      ---! Don't swap the two buffers if their's pinned status not equal.
      if buf_cur.pinned ~= buf_next.pinned then
        return
      end

      meta_tab.bufs[bufid_next] = buf_cur
      meta_tab.bufs[bufid_cur] = buf_next
      status.statusline_dirtier:mark_dirty()
      status.tabline_dirtier:mark_dirty()
    end,
  })
  .register({
    uuid = uuids.buf_swap_right,
    desc = "buf: swap right",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta_tab = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if meta_tab == nil then
        return
      end

      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local buf_cur, bufid_cur = meta_tab:find_buf(bufnr_cur)
      if buf_cur == nil or bufid_cur == nil then
        return
      end

      local step = math.max(1, vim.v.count1 or 1) ---@type integer
      local bufid_next = eve.util.navigate_circular(bufid_cur, step, #meta_tab.bufs) ---@type integer
      if bufid_cur == bufid_next then
        return
      end

      local buf_next = meta_tab.bufs[bufid_next] ---@type eve.t.state.state.tab.meta.IBuf

      ---! Don't swap the two buffers if their's pinned status not equal.
      if buf_cur.pinned ~= buf_next.pinned then
        return
      end

      meta_tab.bufs[bufid_next] = buf_cur
      meta_tab.bufs[bufid_cur] = buf_next
      status.statusline_dirtier:mark_dirty()
      status.tabline_dirtier:mark_dirty()
    end,
  })
