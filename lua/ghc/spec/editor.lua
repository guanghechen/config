return {
  --common
  "nvim-lua/plenary.nvim",
  "MunifTanjim/nui.nvim",
  require("ghc.plugin.nvim-web-devicons"),

  --cmp
  require("ghc.plugin.mini-pairs"),
  require("ghc.plugin.nvim-cmp"),
  require("ghc.plugin.copilot"),
  require("ghc.plugin.copilot-cmp"),
  require("ghc.plugin.nvim-snippets"),

  --code
  require("ghc.plugin.mini-comment"),
  require("ghc.plugin.mini-surround"),

  --diagnostic
  require("ghc.plugin.trouble"),

  --editor
  require("ghc.plugin.indent-blankline"),
  require("ghc.plugin.mini-indentscope"),

  --enhance

  --explorer
  require("ghc.plugin.neo-tree"),
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
  require("ghc.plugin.telescope-file-browser"),
  require("ghc.plugin.telescope-frecency"),
  require("ghc.plugin.telescope-fzf-native"),

  --format
  require("ghc.plugin.conform"),

  --git
  require("ghc.plugin.diffview"),
  require("ghc.plugin.gitsigns"),

  --highlight
  require("ghc.plugin.nvim-treesitter"),
  -- require("ghc.plugin.nvim-treesitter-context"),
  require("ghc.plugin.nvim-treesitter-textobjects"),

  --lsp
  require("ghc.plugin.mason"),
  require("ghc.plugin.nvim-lspconfig"),

  --replace
  require("ghc.plugin.nvim-spectre"),

  --search
  require("ghc.plugin.flash"),

  --ui
  require("ghc.plugin.nvim-colorizer"),
}
