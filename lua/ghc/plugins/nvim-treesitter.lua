-- Treesitter is a new parser generator tool that we can
-- use in Neovim to power faster and more accurate
-- syntax highlighting.
return {
  name = "nvim-treesitter",
  lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
  event = "VeryLazy",
  build = ":TSUpdate",
  cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
  opts = {
    highlight = {
      additional_vim_regex_highlighting = false,
      use_languagetree = true,
      disable = function(_, bufnr)
        local max_filesize = vim.g.bigfile_size or (300 * 1024) -- 300 KB
        local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(bufnr))
        if ok and stats and stats.size > max_filesize then
          return true
        end
      end,
    },
    indent = {
      enable = true,
      disable = { "markdown" },
    },
    matchup = { enable = true },
    ensure_installed = {
      "bash",
      "c",
      "cpp",
      "css",
      "diff",
      "dockerfile",
      "fish",
      "git_config",
      "git_rebase",
      "gitcommit",
      "gitignore",
      "gitattributes",
      "go",
      "gomod",
      "html",
      "javascript",
      "jsdoc",
      "json",
      "json5",
      "jsonc",
      -- "latex",
      "lua",
      "luadoc",
      "luap",
      "make",
      "markdown",
      "markdown_inline",
      "ninja",
      "rst",
      "python",
      "query",
      "regex",
      "rust",
      "sql",
      "toml",
      "tsx",
      "typescript",
      "vim",
      "vimdoc",
      "xml",
      "yaml",
    },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-space>",
        node_incremental = "<C-space>",
        scope_incremental = false,
        node_decremental = "<bs>",
      },
    },
  },
  config = function(_, opts)
    require("nvim-treesitter").setup(opts)
    vim.treesitter.language.register("json", "excalidraw")
  end,
  dependencies = {
    "nvim-treesitter-textobjects",
  },
}
