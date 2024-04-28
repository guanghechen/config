local setup = {
  function(server_name)
    require("lspconfig")[server_name].setup({})
  end,
  clangd = function()
    require("lspconfig").clangd.setup(require("ghc.core.lsp.lang.cpp"))
  end,
  html = function()
    require("lspconfig").html.setup(require("ghc.core.lsp.lang.html"))
  end,
  jsonls = function()
    require("lspconfig").jsonls.setup(require("ghc.core.lsp.lang.json"))
  end,
  lua_ls = function()
    require("lspconfig").lua_ls.setup(require("ghc.core.lsp.lang.lua"))
  end,
  pyright = function()
    require("lspconfig").pyright.setup(require("ghc.core.lsp.lang.python"))
  end,
  tsserver = function()
    require("lspconfig").tsserver.setup(require("ghc.core.lsp.lang.typescript"))
  end,
}

return setup
