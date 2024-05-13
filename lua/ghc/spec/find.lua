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
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-telescope/telescope-fzf-native.nvim",
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
    build = vim.fn.executable("make") == 1 and "make"
      or "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
    enabled = vim.fn.executable("make") == 1 or vim.fn.executable("cmake") == 1,
    config = loadTelescopeExtension("fzf"),
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
}
