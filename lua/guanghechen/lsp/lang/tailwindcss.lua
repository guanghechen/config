local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init
local capabilities = require("guanghechen.lsp.common").capabilities

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  filetypes_exclude = { "markdown" },
  filetypes_include = { "css", "javascriptreact", "javascript.jsx", "typescriptreact", "typescript.tsx" },
  settings = {
    tailwindCSS = {},
  },
}
