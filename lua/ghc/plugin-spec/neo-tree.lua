return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = require("ghc.plugin.neo-tree.opts"),
  dependencies = {
    {
      "s1n7ax/nvim-window-picker",
      name = "window-picker",
      event = "VeryLazy",
      version = "2.*",
      opt = require("ghc.plugin.nvim-window-picker.opts"),
    },
  },
}
