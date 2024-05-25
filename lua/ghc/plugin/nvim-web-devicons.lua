local icons = require("ghc.core.setting.icons")

return {
  "nvim-tree/nvim-web-devicons",
  opts = {
    override = icons.devicons,
  },
  config = function(_, opts)
    dofile(vim.g.base46_cache .. "devicons")
    require("nvim-web-devicons").setup(opts)
  end,
}
