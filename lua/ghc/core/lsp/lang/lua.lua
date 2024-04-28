local on_attach = require("ghc.core.lsp.common").on_attach
local on_init = require("ghc.core.lsp.common").on_init
local capabilities = require("ghc.core.lsp.common").capabilities

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
        disable = { "different-requires" },
      },
      workspace = {
        library = {
          [vim.fn.expand("$VIMRUNTIME/lua")] = true,
          [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
          [vim.fn.stdpath("data") .. "/lazy/ui/nvchad_types"] = true,
          [vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy"] = true,
        },
        checkThirdPart = false,
        maxPreload = 100000,
        preloadFileSize = 10000,
      },
      format = { enable = false },
      telemetry = { enable = false },
      semantic = { enable = false },
    },
  },
}
