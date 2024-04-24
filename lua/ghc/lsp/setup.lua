local setup = {
  function(server_name)
    require("lspconfig")[server_name].setup({})
  end,
  clangd = function()
    require("lspconfig").clangd.setup(require("ghc.lsp.lang.cpp"))
  end,
  lua_ls = function()
    require("lspconfig").lua_ls.setup(require("ghc.lsp.lang.lua"))
  end,
  tsserver = function()
    require("lspconfig").tsserver.setup(require("ghc.lsp.lang.typescript"))
  end,
}

return setup
