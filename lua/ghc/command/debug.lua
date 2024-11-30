local __module_name__ = "ghc.command.debug" ---@type string

local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.debug_inspect,
    desc = "debug: inspect",
    action = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr = vim.api.nvim_tabpage_get_win(tabnr) ---@type integer
      local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
      local buftype = vim.bo[bufnr].buftype ---@type string
      local filetype = vim.bo[bufnr].filetype ---@type string

      local winnr_cur = eve.locations.get_current_winnr() ---@type integer|nil
      local bufnr_cur = eve.locations.get_current_bufnr() ---@type integer|nil

      eve.reporter.info({
        from = __module_name__,
        subject = "inspect",
        details = {
          tabnr = tabnr,
          winnr = winnr,
          bufnr = bufnr,
          buftype = buftype or "nil",
          filetype = filetype or "nil",
          bufnr_cur = bufnr_cur,
          winnr_cur = winnr_cur,
        },
      })
    end,
  })
  .register({
    uuid = uuids.debug_inspect_pos,
    desc = "debug: inspect pos",
    action = function()
      vim.show_pos()
    end,
  })
  .register({
    uuid = uuids.debug_inspect_state,
    desc = "debug: inspect state",
    action = function()
      local data = eve.context.dump() ---@type eve.t.context.data
      eve.reporter.info({
        from = __module_name__,
        subject = "inspect_state",
        details = { data = data },
      })
    end,
  })
  .register({
    uuid = uuids.debug_inspect_tree,
    desc = "debug: inspect tree",
    action = function()
      vim.cmd.InspectTree()
    end,
  })
