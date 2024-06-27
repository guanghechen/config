return {
  "nvim-tree/nvim-web-devicons",
  opts = {
    override = fml.ui.icons.devicons,
  },
  config = function(_, opts)
    ghc.context.shared.reload_partial({ integration = "nvim_web_devicons" })
    require("nvim-web-devicons").setup(opts)
  end,
}
