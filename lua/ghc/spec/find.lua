local function loadTelescopeExtension(ext)
  return function()
    require("telescope").load_extension(ext)
  end
end

return {
  {
    "telescope.nvim",
    opts = require("ghc.plugin.telescope.opts"),
    config = require("ghc.plugin.telescope.config"),
    dependences = {
      "nvim-tree/nvim-web-devicons",
      "nvim-lua/plenary.nvim",
    },
  },
  {
    "nvim-telescope/telescope-frecency.nvim",
    config = loadTelescopeExtension("frecency"),
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = vim.fn.executable("make") == 1 and "make" or "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
    enabled = vim.fn.executable("make") == 1 or vim.fn.executable("cmake") == 1,
    config = loadTelescopeExtension("fzf"),
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "nvim-telescope/telescope-live-grep-args.nvim",
    config = loadTelescopeExtension("live_grep_args"),
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "nvim-telescope/telescope-file-browser.nvim",
    config = loadTelescopeExtension("file_browser"),
    dependencies = {
      "nvim-telescope/telescope.nvim",
    },
  },

  -- Flash enhances the built-in search functionality by showing labels
  -- at the end of each match, letting you quickly jump to a specific location.
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      jump = {
        autojump = true,
      },
    },
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          require("flash").jump()
        end,
        desc = "Flash",
      },
      {
        "S",
        mode = { "n", "o", "x" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },
      {
        "r",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
      {
        "R",
        mode = { "o", "x" },
        function()
          require("flash").treesitter_search()
        end,
        desc = "Treesitter Search",
      },
      {
        "<c-s>",
        mode = { "c" },
        function()
          require("flash").toggle()
        end,
        desc = "Toggle Flash Search",
      },
    },
  },
}
