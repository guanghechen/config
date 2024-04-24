-- load luasnips + cmp related in insert mode only
return {
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      {
        -- snippet plugin
        "L3MON4D3/LuaSnip",
        dependencies = "rafamadriz/friendly-snippets",
        opts = require("ghc.plugin.luasnip.opts"),
        config = require("ghc.plugin.luasnip.config"),
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
    opts = require("ghc.plugin.nvim-cmp.opts"),
    config = function(_, opts)
      require("cmp").setup(opts)
    end,
  },
}
