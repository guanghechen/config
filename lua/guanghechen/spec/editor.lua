return {
  --common
  "nvim-lua/plenary.nvim",
  "MunifTanjim/nui.nvim",
  require("guanghechen.plugin.nvim-web-devicons"),

  --cmp
  require("guanghechen.plugin.mini-pairs"),
  require("guanghechen.plugin.nvim-cmp"),
  require("guanghechen.plugin.copilot"),
  require("guanghechen.plugin.copilot-cmp"),
  require("guanghechen.plugin.nvim-snippets"),

  --code
  require("guanghechen.plugin.mini-comment"),
  require("guanghechen.plugin.mini-surround"),

  --diagnostic
  require("guanghechen.plugin.trouble"),

  --editor
  require("guanghechen.plugin.indent-blankline"),
  require("guanghechen.plugin.mini-indentscope"),

  --enhance

  --explorer
  require("guanghechen.plugin.neo-tree"),
  require("guanghechen.plugin.nvim-window-picker"),

  --fancy
  require("guanghechen.plugin.dressing"),
  require("guanghechen.plugin.noice"),
  require("guanghechen.plugin.nvim-notify"),
  require("guanghechen.plugin.vim-illuminate"),
  require("guanghechen.plugin.which-key"),

  --find
  require("guanghechen.plugin.bookmarks"),
  require("guanghechen.plugin.telescope"),
  require("guanghechen.plugin.telescope-file-browser"),
  require("guanghechen.plugin.telescope-frecency"),
  require("guanghechen.plugin.telescope-fzf-native"),

  --format
  require("guanghechen.plugin.conform"),

  --git
  require("guanghechen.plugin.diffview"),
  require("guanghechen.plugin.gitsigns"),

  --highlight
  require("guanghechen.plugin.nvim-treesitter"),
  -- require("guanghechen.plugin.nvim-treesitter-context"),
  require("guanghechen.plugin.nvim-treesitter-textobjects"),

  --lsp
  require("guanghechen.plugin.mason"),
  require("guanghechen.plugin.nvim-lspconfig"),

  --replace
  require("guanghechen.plugin.nvim-spectre"),

  --search
  require("guanghechen.plugin.flash"),

  --ui
  require("guanghechen.plugin.nvim-colorizer"),
  require("guanghechen.plugin.barbecue"),
}
