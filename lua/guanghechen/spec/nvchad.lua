return {
  {
    "NvChad/ui",
    branch = "v2.5",
    lazy = false,
    config = function()
      local config = require("nvconfig").ui
      if config.tabufline.enabled then
        require("nvchad.tabufline.lazyload")
      end
    end,
  },
}
