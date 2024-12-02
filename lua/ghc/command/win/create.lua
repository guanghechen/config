local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.win_split_horizontal,
    desc = "win: split horizontal",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer

      vim.cmd("split")

      local meta_forked = eve.win.fork_meta(winnr) ---@type eve.t.state.state.win.IMeta|nil
      if meta_forked ~= nil then
        local winnr_new = vim.api.nvim_get_current_win() ---@type integer
        eve.win.set_meta(winnr_new, meta_forked)
      end
    end,
  })
  .register({
    uuid = uuids.win_split_vertical,
    desc = "win: split vertical",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer

      vim.cmd("vsplit")

      local meta_forked = eve.win.fork_meta(winnr) ---@type eve.t.state.state.win.IMeta|nil
      if meta_forked ~= nil then
        local winnr_new = vim.api.nvim_get_current_win() ---@type integer
        eve.win.set_meta(winnr_new, meta_forked)
      end
    end,
  })
