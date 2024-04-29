---@class ghc.plugin.nvim_notify.opts.setting
local setting = {
  icons = require("ghc.core.setting.icons"),
}

local opts = {
  stages = "static",
  timeout = 3000,
  fps = 20,
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
    ERROR = setting.icons.diagnostics.Error,
    WARN = setting.icons.diagnostics.Warning,
    INFO = setting.icons.diagnostics.Information,
    DEBUG = setting.icons.ui.Bug,
    TRACE = setting.icons.ui.Pencil,
  },
}

return opts
