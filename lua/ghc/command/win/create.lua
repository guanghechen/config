local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.win_split_horizontal,
    desc = "win: split horizontal",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer

      vim.cmd("split")

      local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
      if meta ~= nil then
        ---@type eve.t.state.state.win.IMeta
        local meta_cloned = {
          filepath_history = meta.filepath_history:fork({ name = "win_filepath" }),
          lsp_symbols = vim.list_slice(meta.lsp_symbols),
        }

        local winnr_new = vim.api.nvim_get_current_win() ---@type integer
        eve.win.set_meta(winnr_new, meta_cloned)
      end
    end,
  })
  .register({
    uuid = uuids.win_split_vertical,
    desc = "win: split vertical",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer

      vim.cmd("vsplit")

      local meta = eve.win.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
      if meta ~= nil then
        ---@type eve.t.state.state.win.IMeta
        local meta_cloned = {
          filepath_history = meta.filepath_history:fork({ name = "win_filepath" }),
          lsp_symbols = vim.list_slice(meta.lsp_symbols),
        }

        local winnr_new = vim.api.nvim_get_current_win() ---@type integer
        eve.win.set_meta(winnr_new, meta_cloned)
      end
    end,
  })
