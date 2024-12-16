local capabilities = require("guanghechen.lsp.common").capabilities
local handlers = require("guanghechen.lsp.common").handlers
local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init

local setup = {
  function(server_name)
    require("lspconfig")[server_name].setup({
      capabilities = capabilities,
      handlers = handlers,
      on_attach = on_attach,
      on_init = on_init,
    })
  end,
  clangd = function()
    require("lspconfig").clangd.setup(require("guanghechen.lsp.lang.cpp"))
  end,
  eslint = function()
    require("lspconfig").eslint.setup(require("guanghechen.lsp.lang.eslint"))
  end,
  html = function()
    require("lspconfig").html.setup(require("guanghechen.lsp.lang.html"))
  end,
  jsonls = function()
    require("lspconfig").jsonls.setup(require("guanghechen.lsp.lang.json"))
  end,
  lua_ls = function()
    require("lspconfig").lua_ls.setup(require("guanghechen.lsp.lang.lua"))
  end,
  pyright = function()
    require("lspconfig").pyright.setup(require("guanghechen.lsp.lang.python"))
  end,
  rust_analyzer = function()
    require("lspconfig").rust_analyzer.setup(require("guanghechen.lsp.lang.rust"))
  end,
  tailwindcss = function()
    require("lspconfig").tailwindcss.setup(require("guanghechen.lsp.lang.tailwindcss"))
  end,
  ts_ls = function()
    require("lspconfig").ts_ls.setup(require("guanghechen.lsp.lang.typescript"))
  end,
}

return setup
