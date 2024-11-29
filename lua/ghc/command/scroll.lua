local uuids = eve.commander.uuids ---@type eve.builtin.commander.uuids

eve.commander
  .register({
    uuid = uuids.scroll_down_half_window,
    desc = "scroll: down (half window)",
    action = function()
      local lines = vim.api.nvim_win_get_height(0) ---@type integer
      local half = math.floor(lines / 2) ---@type integer
      local keys = vim.api.nvim_replace_termcodes("" .. half .. "j", true, false, true) ---@type string
      vim.api.nvim_feedkeys(keys, "n", true)
    end,
  })
  .register({
    uuid = uuids.scroll_up_half_window,
    desc = "scroll: up (half window)",
    action = function()
      local lines = vim.api.nvim_win_get_height(0) ---@type integer
      local half = math.floor(lines / 2) ---@type integer
      local keys = vim.api.nvim_replace_termcodes("" .. half .. "k", true, false, true) ---@type string
      vim.api.nvim_feedkeys(keys, "n", true)
    end,
  })
