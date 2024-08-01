local opts = {
  spec = {
    --common
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    require("guanghechen.plugin.mini-icons"),

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
    require("guanghechen.plugin.telescope"),
    require("guanghechen.plugin.telescope-file-browser"),
    require("guanghechen.plugin.telescope-fzf-native"),

    --format
    require("guanghechen.plugin.conform"),

    --git
    require("guanghechen.plugin.diffview"),
    require("guanghechen.plugin.gitsigns"),

    --lsp
    require("guanghechen.plugin.mason"),
    require("guanghechen.plugin.nvim-lspconfig"),

    --search
    require("guanghechen.plugin.flash"),

    --ui
    require("guanghechen.plugin.nvim-colorizer"),
    require("guanghechen.plugin.nvim-treesitter"),
    -- require("guanghechen.plugin.nvim-treesitter-context"),
    require("guanghechen.plugin.nvim-treesitter-textobjects"),
  },
  defaults = {
    lazy = true,
  },
  install = {
    colorscheme = {},
  },
  checker = {
    enabled = false, -- set true to automatically check for plugin updates
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "2html_plugin",
        "bugreport",
        "compiler",
        "ftplugin",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "matchit",
        "matchparen",
        "netrw",
        "netrwFileHandlers",
        "netrwPlugin",
        "netrwSettings",
        "optwin",
        "rplugin",
        "rrhelper",
        "spellfile_plugin",
        "synmenu",
        "syntax",
        "tar",
        "tarPlugin",
        "tohtml",
        "tutor",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
      },
    },
  },
  ui = {
    icons = {
      ft = "",
      lazy = "󰂠 ",
      loaded = "",
      not_loaded = "",
    },
  },
}

return opts
