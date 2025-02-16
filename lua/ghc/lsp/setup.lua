local get_capabilities = require("ghc.lsp.common").get_capabilities
local handlers = require("ghc.lsp.common").handlers
local on_attach = require("ghc.lsp.common").on_attach
local on_init = require("ghc.lsp.common").on_init

local setup = {
  function(server_name)
    local capabilities = get_capabilities()

    require("lspconfig")[server_name].setup({
      capabilities = capabilities,
      handlers = handlers,
      on_attach = on_attach,
      on_init = on_init,
    })
  end,
  clangd = function()
    local get_config = require("ghc.lsp.lang.cpp")
    require("lspconfig").clangd.setup(get_config())
  end,
  eslint = function()
    local get_config = require("ghc.lsp.lang.eslint")
    require("lspconfig").eslint.setup(get_config())
  end,
  html = function()
    local get_config = require("ghc.lsp.lang.html")
    require("lspconfig").html.setup(get_config())
  end,
  jsonls = function()
    local get_config = require("ghc.lsp.lang.json")
    require("lspconfig").jsonls.setup(get_config())
  end,
  lua_ls = function()
    local get_config = require("ghc.lsp.lang.lua")
    require("lspconfig").lua_ls.setup(get_config())
  end,
  pyright = function()
    local get_config = require("ghc.lsp.lang.python")
    require("lspconfig").pyright.setup(get_config())
  end,
  rust_analyzer = function()
    local get_config = require("ghc.lsp.lang.rust")
    require("lspconfig").rust_analyzer.setup(get_config())
  end,
  tailwindcss = function()
    local get_config = require("ghc.lsp.lang.tailwindcss")
    require("lspconfig").tailwindcss.setup(get_config())
  end,
  vtsls = function()
    local get_config = require("ghc.lsp.lang.typescript")
    require("lspconfig").vtsls.setup(get_config())
  end,
}

return setup
