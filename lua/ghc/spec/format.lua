return {
  {
    "stevearc/conform.nvim",
    cmd = "ConformInfo",
    event = { "VeryLazy" },
    keys = {
      { "=", mode = { "n", "v" } },
    },
    opts = require("ghc.plugin.conform.opts"),
    config = require("ghc.plugin.conform.config"),
  },
}
