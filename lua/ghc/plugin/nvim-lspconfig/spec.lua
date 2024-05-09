return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  config = function()
    dofile(vim.g.base46_cache .. "lsp")
    require("nvchad.lsp")
  end,
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
}
