return {
  "nvim-telescope/telescope-fzf-native.nvim",
  build = vim.fn.executable("make") == 1 and "make"
    or "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
  enabled = vim.fn.executable("make") == 1 or vim.fn.executable("cmake") == 1,
  config = function()
    require("telescope").load_extension("fzf")
  end,
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
}
