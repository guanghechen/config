return {
  "nvim-tree/nvim-web-devicons",
  config = function()
    dofile(vim.g.base46_cache .. "devicons")
    require("nvim-web-devicons").setup({
      override = require("nvchad.icons.devicons"),
    })
  end,
}
