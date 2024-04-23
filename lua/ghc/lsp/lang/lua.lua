local on_attach = require("ghc.lsp.common").on_attach
local on_init = require("ghc.lsp.common").on_init
local capabilities = require("ghc.lsp.common").capabilities

return {
  settings = {
    Lua = {
      on_attach = on_attach,
      on_init = on_init,
      capabilities = capabilities,
      diagnostics = {
        globals = {'vim'},
      },
      workspace = {
        library = {
          vim.env.VIMRUNTIME
        },
        checkThirdPart = false,
        maxPreload = 100000,
        preloadFileSize = 10000,
      }
    }
  }
}

