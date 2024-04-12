return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = require("ghc.plugin.neo-tree.opts"),
  dependencies = {
    {
      "s1n7ax/nvim-window-picker",
      name = "window-picker",
      event = "VeryLazy",
      version = "2.*",
      config = function()
        require("window-picker").setup({
          hint = "floating-big-letter",
          show_prompt = true,
          filter_rules = {
            autoselect_one = true,
            include_current_win = false,
            bo = {
              filetype = { "neo-tree", "neo-tree-popup", "notify" },
              buftype = { "terminal", "quickfix" },
            },
          },
        })
      end,
    },
  },
}
