local setting = {
  icons = {
    diagnostics = require("ghc.core.setting.ui").icons.get("diagnostics"),
    ui = require("ghc.core.setting.ui").icons.get("ui"),
  },
}

return {
  -- util library
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },

  -- icons
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
    config = function()
      dofile(vim.g.base46_cache .. "devicons")
      require("nvim-web-devicons").setup({
        override = require("nvchad.icons.devicons"),
      })
    end,
  },

  -- ui components
  {
    "MunifTanjim/nui.nvim",
    lazy = true,
  },

  -- Better `vim.notify()`
  {
    "rcarriga/nvim-notify",
    opts = {
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
    },
    config = function(_, opts)
      require("notify").setup(opts)
      vim.notify = require("notify")
    end,
  },
}
