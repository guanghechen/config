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
    max_height = function()
      return math.floor(vim.o.lines * 0.75)
    end,
    max_width = function()
      return math.floor(vim.o.columns * 0.75)
    end,
    on_open = function(win)
      vim.api.nvim_set_option_value("winblend", 0, { scope = "local", win = win })
      vim.api.nvim_win_set_config(win, { zindex = 100 })
    end,
    icons = {
      ERROR = eve.icons.diagnostics.Error,
      WARN = eve.icons.diagnostics.Warning,
      INFO = eve.icons.diagnostics.Information,
      DEBUG = eve.icons.ui.Bug,
      TRACE = eve.icons.ui.Pencil,
    },
  },
}
