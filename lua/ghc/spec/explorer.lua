return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    deactivate = function()
      vim.cmd([[Neotree close]])
    end,
    init = function()
      -- Initial open the neo-tree if nvim enter with a directory.
      -- if vim.fn.argc(-1) == 1 then
      --   local stat = vim.uv.fs_stat(vim.fn.argv(0))
      --   if stat and stat.type == "directory" then
      --     require("neo-tree")
      --   end
      -- end
    end,
    keys = {},
    opts = require("ghc.plugin.neo-tree.opts"),
    config = require("ghc.plugin.neo-tree.config"),
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
  },
  {
    "s1n7ax/nvim-window-picker",
    name = "window-picker",
    event = "VeryLazy",
    version = "2.*",
    config = require("ghc.plugin.nvim-window-picker.config"),
  },
}
