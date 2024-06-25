local have_make = vim.fn.executable("make") == 1 ---@type boolean
local have_cmake = vim.fn.executable("cmake") == 1 ---@type boolean

return {
  "nvim-telescope/telescope-fzf-native.nvim",
  build = have_make and "make"
    or "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
  enabled = have_make or have_cmake,
  config = function()
    require("telescope").load_extension("fzf")
  end,
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
}
