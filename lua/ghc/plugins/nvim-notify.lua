-- Better `vim.notify()`
return {
  name = "nvim-notify",
  init = function()
    vim.schedule(function()
      vim.notify = require("notify")
    end)
  end,
  opts = {
    stages = "static",
    timeout = 3000,
    level = "INFO",
    background_colour = "NotifyBackground",
    max_height = function()
      return math.floor(vim.o.lines * 0.75)
    end,
    max_width = function()
      return math.floor(vim.o.columns * 0.75)
    end,
    on_open = function(winnr)
      local winblend = eve.state.theme.get_float_winblend() ---@type integer
      vim.wo[winnr].winblend = winblend
      vim.api.nvim_win_set_config(winnr, { zindex = 100 })
    end,
    icons = {
      ERROR = eve.icon.diagnostic.Error,
      WARN = eve.icon.diagnostic.Warning,
      INFO = eve.icon.diagnostic.Information,
      DEBUG = eve.icon.ui.Bug,
      TRACE = eve.icon.ui.Pencil,
    },
  },
}
