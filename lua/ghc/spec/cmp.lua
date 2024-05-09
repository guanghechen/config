-- load luasnips + cmp related in insert mode only
return {
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    main = "cmp",
    opts = require("ghc.plugin.nvim-cmp.opts"),
    dependencies = {
      {
        -- snippet plugin
        "L3MON4D3/LuaSnip",
        opts = require("ghc.plugin.luasnip.opts"),
        config = require("ghc.plugin.luasnip.config"),
        dependencies = {
          "rafamadriz/friendly-snippets",
        },
      },

      -- cmp sources plugins
      {
        "saadparwaiz1/cmp_luasnip",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
      },
    },
  },
}
