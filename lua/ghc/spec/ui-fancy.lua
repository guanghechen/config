return {
  -- Active indent guide and indent text objects. When you're browsing
  -- code, this highlights the current level of indentation, and animates
  -- the highlighting.
  {
    "echasnovski/mini.indentscope",
    version = false, -- wait till new 0.7.0 release to put it back on semver
    event = { "VeryLazy" },
    opts = {
      symbol = "│",
      options = {
        try_as_border = true,
      },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
          "term",
        },
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },

  -- better vim.ui input/select
  {
    "stevearc/dressing.nvim",
    lazy = true,
    opts = {
      input = {
        insert_only = false,
        start_in_insert = false,
      },
    },
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.select(...)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.input(...)
      end
    end,
  },

  -- Automatically highlights other instances of the word under your cursor.
  -- This works with LSP, Treesitter, and regexp matching to find the other instances.
  {
    "RRethy/vim-illuminate",
    event = { "VeryLazy" },
    keys = {
      { "]]", desc = "Next Reference" },
      { "[[", desc = "Prev Reference" },
    },
    opts = require("ghc.plugin.vim-illuminate.opts"),
    config = require("ghc.plugin.vim-illuminate.config"),
  },

  -- Better `vim.notify()`
  {
    "rcarriga/nvim-notify",
    opts = require("ghc.plugin.nvim-notify.opts"),
    config = require("ghc.plugin.nvim-notify.config"),
  },

  -- Highly experimental plugin that completely replaces the UI for messages, cmdline and the popupmenu.
  {
    "folke/noice.nvim",
    event = { "VeryLazy" },
    opts = require("ghc.plugin.noice.opts"),
    -- stylua: ignore
    keys = {
      { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll Forward", mode = {"i", "n", "s"} },
      { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll Backward", mode = {"i", "n", "s"}},
    },
  },

  {
    "folke/which-key.nvim",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "whichkey")
      require("which-key").setup(opts)
      require("which-key").register(opts.defaults)
    end,
    cmd = "WhichKey",
    keys = { "<leader>", '"', "'", "`", "c", "v", "g" },
    opts = {
      plugins = { spelling = true },
      defaults = {
        mode = { "n", "v" },
        ["g"] = { name = "+goto" },
        ["gs"] = { name = "+surround" },
        ["z"] = { name = "+fold" },
        ["]"] = { name = "+next" },
        ["["] = { name = "+prev" },
        ["<leader>b"] = { name = "+buffer" },
        ["<leader>c"] = { name = "+code" },
        ["<leader>e"] = { name = "+explorer" },
        ["<leader>f"] = { name = "+find/file" },
        ["<leader>g"] = { name = "+find/git" },
        ["<leader>gh"] = { name = "git action" },
        ["<leader>q"] = { name = "+quit/session" },
        ["<leader>s"] = { name = "+search" },
        ["<leader>sn"] = { name = "+noice" },
        ["<leader>t"] = { name = "+tab/terminal" },
        ["<leader>u"] = { name = "+ui" },
        ["<leader>w"] = { name = "+window" },
        ["<leader>x"] = { name = "+diagnostics/quickfix" },
      },
    },
  },

  {
    "alexghergh/nvim-tmux-navigation",
    lazy = false,
    opts = {
      disable_when_zoomed = true,
    },
  },
}
