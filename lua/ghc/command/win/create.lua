local state = require("eve.state")
local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.win_split_horizontal,
    desc = "win: split horizontal",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer

      vim.cmd("split")

      local meta_forked = state.win.fork(winnr) ---@type eve.t.state.win.meta.state|nil
      if meta_forked ~= nil then
        local winnr_new = vim.api.nvim_get_current_win() ---@type integer
        state.win.set(winnr_new, meta_forked)
      end
    end,
  })
  .register({
    uuid = uuids.win_split_vertical,
    desc = "win: split vertical",
    action = function()
      local winnr = vim.api.nvim_get_current_win() ---@type integer

      vim.cmd("vsplit")

      local meta_forked = state.win.fork(winnr) ---@type eve.t.state.win.meta.state|nil
      if meta_forked ~= nil then
        local winnr_new = vim.api.nvim_get_current_win() ---@type integer
        state.win.set(winnr_new, meta_forked)
      end
    end,
  })
