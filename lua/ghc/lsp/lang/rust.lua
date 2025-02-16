local get_capabilities = require("ghc.lsp.common").get_capabilities
local handlers = require("ghc.lsp.common").handlers
local on_attach = require("ghc.lsp.common").on_attach
local on_init = require("ghc.lsp.common").on_init

return function()
  local capabilities = get_capabilities()

  return {
    capabilities = capabilities,
    handlers = handlers,
    on_attach = on_attach,
    on_init = on_init,
    settings = {
      ["rust-analyzer"] = {
        check = {
          command = "clippy",
        },
        completion = {
          limit = 69,
          privateEditable = {
            enable = true,
          },
        },
        imports = {
          merge = {
            blob = false,
          },
        },
        procMacro = {
          enable = true,
        },
      },
    },
  }
end
