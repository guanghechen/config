local on_attach = require("ghc.lsp.common").on_attach
local on_init = require("ghc.lsp.common").on_init
local capabilities = require("ghc.lsp.common").capabilities

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = {'vim'},
      },
      workspace = {
        library = {},
        checkThirdPart = false,
        maxPreload = 100000,
        preloadFileSize = 10000,
      }
    }
  }
}

