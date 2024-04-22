return {
  -- git signs highlights text that has changed since the list
  -- git commit, and also lets you interactively stage & unstage
  -- hunks in a commit.
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufWritePost", "VeryLazy" },
    opts = require("ghc.plugin.gitsigns.opts"),
    config = require("ghc.plugin.gitsigns.config"),
  },
}
