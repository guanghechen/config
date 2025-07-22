-- Treesitter is a new parser generator tool that we can
-- use in Neovim to power faster and more accurate
-- syntax highlighting.
return {
  name = "nvim-treesitter",
  lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
  event = "VeryLazy",
  build = ":TSUpdate",
  cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
  keys = {
    { "<C-space>", desc = "Increment Selection" },
    { "<bs>", desc = "Decrement Selection", mode = "x" },
  },
  init = function(plugin)
    -- add nvim-treesitter queries to the rtp and it's custom query predicates early
    -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
    -- no longer trigger the **nvim-treesitter** module to be loaded in time.
    -- Luckily, the only things that those plugins need are the custom queries, which we make available
    -- during startup.
    require("lazy.core.loader").add_to_rtp(plugin)
    require("nvim-treesitter.query_predicates")
  end,
  opts = {
    highlight = {
      enable = not vim.g.vscode,
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
    textobjects = {
      move = {
        enable = true,
        set_jumps = true,
        goto_next_start = {
          ["]a"] = "@parameter.inner",
          ["]b"] = "@block.outer",
          ["]c"] = "@class.outer",
          ["]f"] = "@function.outer",
          ["]s"] = { query = "@local.scope", query_group = "locals", desc = "goto: next scope" },
          ["]z"] = { query = "@fold", query_group = "folds", desc = "goto: next fold" },
        },
        goto_next_end = {
          ["]A"] = "@parameter.inner",
          ["]C"] = "@class.outer",
          ["]F"] = "@function.outer",
        },
        goto_previous_start = {
          ["[a"] = "@parameter.inner",
          ["[b"] = "@block.outer",
          ["[c"] = "@class.outer",
          ["[f"] = "@function.outer",
          ["[s"] = { query = "@local.scope", query_group = "locals", desc = "goto: prev scope" },
          ["[z"] = { query = "@fold", query_group = "folds", desc = "goto: prev fold" },
        },
        goto_previous_end = {
          ["[A"] = "@parameter.inner",
          ["[C"] = "@class.outer",
          ["[F"] = "@function.outer",
        },
      },
    },
  },
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
    
    -- Configure excalidraw filetype to use JSON parser
    vim.treesitter.language.register("json", "excalidraw")
  end,
  dependencies = {
    "nvim-treesitter-textobjects",
  },
}
