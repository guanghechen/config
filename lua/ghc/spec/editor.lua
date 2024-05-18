return {
  --common
  "nvim-lua/plenary.nvim",
  "MunifTanjim/nui.nvim",
  require("ghc.plugin.nvim-web-devicons"),

  --cmp
  require("ghc.plugin.nvim-cmp"),
  require("ghc.plugin.luasnip"),

  --code
  require("ghc.plugin.mini-comment"),
  require("ghc.plugin.mini-surround"),
  require("ghc.plugin.mini-pairs"),

  --diagnostic
  require("ghc.plugin.trouble"),

  --editor
  require("ghc.plugin.indent-blankline"),
  require("ghc.plugin.mini-indentscope"),

  --enhance
  require("ghc.plugin.flash"),
  require("ghc.plugin.nvim-tmux-navigation"),

  --explorer
  require("ghc.plugin.neo-tree.spec"),
  require("ghc.plugin.nvim-window-picker"),

  --fancy
  require("ghc.plugin.dressing"),
  require("ghc.plugin.noice"),
  require("ghc.plugin.nvim-notify"),
  require("ghc.plugin.vim-illuminate"),
  require("ghc.plugin.which-key"),

  --find
  require("ghc.plugin.bookmarks"),
  require("ghc.plugin.telescope"),

  --format
  require("ghc.plugin.conform"),

  --git
  require("ghc.plugin.gitsigns"),

  --highlight
  require("ghc.plugin.nvim-treesitter"),
  require("ghc.plugin.nvim-treesitter-context"),
  require("ghc.plugin.nvim-treesitter-textobjects"),

  --lsp
  require("ghc.plugin.mason"),
  require("ghc.plugin.nvim-lspconfig"),

  --search

  --ui
  require("ghc.plugin.nvim-colorizer"),
}
