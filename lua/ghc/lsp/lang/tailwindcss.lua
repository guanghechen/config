local get_capabilities = require("ghc.lsp.common").get_capabilities
local handlers = require("ghc.lsp.common").handlers
local locate_lsp_root = require("ghc.lsp.common").locate_lsp_root
local on_attach = require("ghc.lsp.common").on_attach
local on_init = require("ghc.lsp.common").on_init

---@type string[]
local CONFIG_FILENAMES = {
  "tailwind.config.ts",
  "tailwind.config.js",
  "tailwind.config.mjs",
}

return function()
  local capabilities = get_capabilities()

  return {
    capabilities = capabilities,
    handlers = handlers,
    on_attach = on_attach,
    on_init = on_init,
    filetypes_exclude = { "markdown" },
    filetypes_include = { "css", "javascriptreact", "javascript.jsx", "typescriptreact", "typescript.tsx" },
    root_dir = function(filename)
      return locate_lsp_root(filename, CONFIG_FILENAMES)
    end,
    settings = {
      tailwindCSS = {
        includeLanguages = {
          elixir = "html-eex",
          eelixir = "html-eex",
          heex = "html-eex",
        },
      },
    },
  }
end
