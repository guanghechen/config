local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init
local capabilities = require("guanghechen.lsp.common").capabilities
local locate_lsp_root = require("guanghechen.lsp.common").locate_lsp_root

---@type string[]
local CONFIG_FILENAMES = {
  "tailwind.config.ts",
  "tailwind.config.js",
}

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  filetypes_exclude = { "markdown" },
  filetypes_include = { "css", "javascriptreact", "javascript.jsx", "typescriptreact", "typescript.tsx" },
  root_dir = function(filename)
    return locate_lsp_root(filename, CONFIG_FILENAMES)
  end,
  settings = {
    tailwindCSS = {},
  },
}
