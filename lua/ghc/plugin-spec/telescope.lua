local function loadTelescopeExtension(ext)
  return function()
    require("telescope").load_extension(ext)
  end
end

return {
  {
    "telescope.nvim",
    keys = require("ghc.plugin.telescope.keys"),
    opts = require("ghc.plugin.telescope.opts"),
  },
  {
    "nvim-telescope/telescope-frecency.nvim",
    config = loadTelescopeExtension("frecenry"),
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
      "nvim-lua/plenary.nvim",
    },
  },
}
