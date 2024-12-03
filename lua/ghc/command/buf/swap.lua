local status = require("eve.builtin.status")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.buf_swap_left,
    desc = "buf: swap left",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if meta == nil then
        return
      end

      local step = math.max(1, vim.v.count1 or 1) ---@type integer
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local bufid_cur = eve.util.find_index(meta.bufnrs, bufnr_cur) ---@type integer|nil

      if bufid_cur ~= nil then
        local bufid_next = eve.util.navigate_circular(bufid_cur, -step, #meta.bufnrs)
        if bufid_cur ~= bufid_next then
          local bufnr_next = meta.bufnrs[bufid_next]
          meta.bufnrs[bufid_next] = bufnr_cur
          meta.bufnrs[bufid_cur] = bufnr_next
          status.statusline_dirtier:mark_dirty()
          status.tabline_dirtier:mark_dirty()
        end
      end
    end,
  })
  .register({
    uuid = uuids.buf_swap_right,
    desc = "buf: swap right",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local meta = eve.tab.resolve(tabnr) ---@type eve.t.state.state.tab.IMeta|nil
      if meta == nil then
        return
      end

      local step = math.max(1, vim.v.count1 or 1) ---@type integer
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local bufid_cur = eve.util.find_index(meta.bufnrs, bufnr_cur) ---@type integer|nil

      if bufid_cur ~= nil then
        local bufid_next = eve.util.navigate_circular(bufid_cur, step, #meta.bufnrs)
        if bufid_cur ~= bufid_next then
          local bufnr_next = meta.bufnrs[bufid_next]
          meta.bufnrs[bufid_next] = bufnr_cur
          meta.bufnrs[bufid_cur] = bufnr_next
          status.statusline_dirtier:mark_dirty()
          status.tabline_dirtier:mark_dirty()
        end
      end
    end,
  })
