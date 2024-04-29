return {
  -- nvchad
  {
    "NvChad/ui",
    branch = "v2.5",
    lazy = false,
    config = function()
      require("nvchad")
    end,
  },
  {
    "NvChad/base46",
    branch = "v2.5",
    build = function()
      require("base46").load_all_highlights()
    end,
  },
  {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPre", "BufWritePost", "VeryLazy" },
    opts = require("ghc.plugin.nvim-colorizer.opts"),
    config = require("ghc.plugin.nvim-colorizer.config"),
  },

  -- indent guides for Neovim
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost" },
    main = "ibl",
    opts = require("ghc.plugin.indent-blankline.opts"),
    config = require("ghc.plugin.indent-blankline.config"),
  },
}
