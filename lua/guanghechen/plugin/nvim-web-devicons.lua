return {
  "nvim-tree/nvim-web-devicons",
  opts = {
    override = fml.ui.icons.devicons,
  },
  config = function(_, opts)
    require("nvim-web-devicons").setup(opts)
  end,
}
