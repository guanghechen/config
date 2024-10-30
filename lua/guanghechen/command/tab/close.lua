local uuids = eve.commander.uuids ---@type eve.std.commander.uuids

eve.commander
  .register({
    uuid = uuids.tab_close,
    desc = "tab: close current",
    action = function()
      local tab_count = vim.fn.tabpagenr("$") ---@type integer
      if tab_count <= 1 then
        eve.reporter.warn({
          from = "fml.api.tab",
          subject = "close_current",
          message = "This is the last tab, cannot close it.",
        })
        return
      end

      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      eve.context.state.tabs[tabnr] = nil
      vim.cmd("tabclose")
    end,
  })
  .register({
    uuid = uuids.tab_close_to_leftest,
    desc = "tab: close to leftest",
    action = function()
      local tabpages = vim.api.nvim_list_tabpages() ---@type integer[]
      local tabid_cur = vim.fn.tabpagenr() ---@type integer

      for i = 1, tabid_cur - 1, 1 do
        local tabnr = tabpages[i] ---@type integer
        eve.context.state.tabs[tabnr] = nil
      end

      for _ = 1, tabid_cur - 1, 1 do
        vim.cmd("-tabclose")
      end
    end,
  })
  .register({
    uuid = uuids.tab_close_to_rightest,
    desc = "tab: close to rightest",
    action = function()
      local tabpages = vim.api.nvim_list_tabpages() ---@type integer[]
      local tabid_cur = vim.fn.tabpagenr() ---@type integer
      local N = #tabpages ---@type integer

      for i = tabid_cur + 1, N, 1 do
        local tabnr = tabpages[i] ---@type integer
        eve.context.state.tabs[tabnr] = nil
      end

      for _ = tabid_cur + 1, N, 1 do
        vim.cmd("+tabclose")
      end
    end,
  })
  .register({
    uuid = uuids.tab_close_others,
    desc = "tab: close others",
    action = function()
      local tabpages = vim.api.nvim_list_tabpages() ---@type integer[]
      local tabnr_cur = vim.api.nvim_get_current_tabpage() ---@type integer
      vim.cmd("tabonly")

      for _, tabnr in ipairs(tabpages) do
        eve.context.state.tabs[tabnr] = nil
      end

      eve.context.state.tab_history:clear()
      eve.context.state.tab_history:push(tabnr_cur)
    end,
  })
