local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander
  .register({
    uuid = uuids.buf_swap_left,
    desc = "buf: swap left",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab = fml.api.tab.get(tabnr) ---@type eve.t.context.state.tab.IItem|nil
      if tab == nil then
        return
      end

      local step = math.max(1, vim.v.count1 or 1) ---@type integer
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local bufid_cur = eve.array.first(tab.bufnrs, bufnr_cur) ---@type integer|nil

      if bufid_cur ~= nil then
        local bufid_next = eve.util.navigate_circular(bufid_cur, -step, #tab.bufnrs)
        if bufid_cur ~= bufid_next then
          local bufnr_next = tab.bufnrs[bufid_next]
          tab.bufnrs[bufid_next] = bufnr_cur
          tab.bufnrs[bufid_cur] = bufnr_next
          vim.cmd("redrawtabline")
        end
      end
    end,
  })
  .register({
    uuid = uuids.buf_swap_right,
    desc = "buf: swap right",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tab = fml.api.tab.get(tabnr) ---@type eve.t.context.state.tab.IItem|nil
      if tab == nil then
        return
      end

      local step = math.max(1, vim.v.count1 or 1) ---@type integer
      local bufnr_cur = vim.api.nvim_get_current_buf() ---@type integer
      local bufid_cur = eve.array.first(tab.bufnrs, bufnr_cur) ---@type integer|nil

      if bufid_cur ~= nil then
        local bufid_next = eve.util.navigate_circular(bufid_cur, step, #tab.bufnrs)
        if bufid_cur ~= bufid_next then
          local bufnr_next = tab.bufnrs[bufid_next]
          tab.bufnrs[bufid_next] = bufnr_cur
          tab.bufnrs[bufid_cur] = bufnr_next
          vim.cmd("redrawtabline")
        end
      end
    end,
  })
