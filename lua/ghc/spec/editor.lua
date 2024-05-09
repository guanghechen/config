return {
  --common
  "nvim-lua/plenary.nvim",
  "MunifTanjim/nui.nvim",
  require("ghc.plugin.nvim-web-devicons.spec"),

  --cmp
  require("ghc.plugin.nvim-cmp.spec"),
  require("ghc.plugin.luasnip.spec"),

  --code
  require("ghc.plugin.mini-comment.spec"),
  require("ghc.plugin.mini-surround.spec"),
  require("ghc.plugin.mini-pairs.spec"),

  --diagnostic
  require("ghc.plugin.trouble.spec"),

  --editor
  require("ghc.plugin.indent-blankline.spec"),
  require("ghc.plugin.mini-indentscope.spec"),

  --enhance
  require("ghc.plugin.flash.spec"),
  require("ghc.plugin.nvim-tmux-navigation.spec"),

  --explorer
  require("ghc.plugin.neo-tree.spec"),
  require("ghc.plugin.nvim-window-picker.spec"),

  --fancy
  require("ghc.plugin.dressing.spec"),
  require("ghc.plugin.noice.spec"),
  require("ghc.plugin.nvim-notify.spec"),
  require("ghc.plugin.vim-illuminate.spec"),
  require("ghc.plugin.which-key.spec"),

  --find
  require("ghc.plugin.bookmarks.spec"),

  --format
  require("ghc.plugin.conform.spec"),

  --git
  require("ghc.plugin.gitsigns.spec"),

  --highlight
  require("ghc.plugin.nvim-treesitter.spec"),
  require("ghc.plugin.nvim-treesitter-context.spec"),
  require("ghc.plugin.nvim-treesitter-textobjects.spec"),

  --lsp
  require("ghc.plugin.mason.spec"),
  require("ghc.plugin.nvim-lspconfig.spec"),

  --search

  --ui
  require("ghc.plugin.nvim-colorizer.spec"),
}
