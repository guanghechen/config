local capabilities = require("guanghechen.lsp.common").capabilities
local handlers = require("guanghechen.lsp.common").handlers
local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  handlers = handlers,
  settings = {
    pyright = {
      enabled = true,
    },
  },
}
