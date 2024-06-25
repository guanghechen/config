local on_attach = require("guanghechen.core.lsp.common").on_attach
local on_init = require("guanghechen.core.lsp.common").on_init
local capabilities = require("guanghechen.core.lsp.common").capabilities

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    pyright = {
      enabled = true,
    },
  },
}
