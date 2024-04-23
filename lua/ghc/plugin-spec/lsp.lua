return {
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },
    build = ":MasonUpdate",
    opts = require("ghc.plugin.mason.opts"),
    config = require("ghc.plugin.mason.config"),
    dependencies = {
      "neovim/nvim-lspconfig",
      {
        "williamboman/mason-lspconfig.nvim",
        opts = require("ghc.plugin.mason-lspconfig.opts"),
      }
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufWritePost", "VeryLazy" },
    opts = require("ghc.plugin.nvim-lspconfig.opts"),
    config = require("ghc.plugin.nvim-lspconfig.config"),
  },
}

