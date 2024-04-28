---@class ghc.spec.common.setting
local setting = {
  icons = require("ghc.core.setting.icons"),
}

return {
  -- Active indent guide and indent text objects. When you're browsing
  -- code, this highlights the current level of indentation, and animates
  -- the highlighting.
  {
    "echasnovski/mini.indentscope",
    version = false, -- wait till new 0.7.0 release to put it back on semver
    event = { "VeryLazy" },
    opts = {
      symbol = "│",
      options = {
        try_as_border = true,
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
          "term",
        },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },

  -- better vim.ui input/select
  {
    "stevearc/dressing.nvim",
    lazy = true,
    opts = {
      input = {
        insert_only = false,
        start_in_insert = false,
      },
    },
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.select(...)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.input(...)
      end
    end,
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
