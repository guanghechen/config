local on_attach = require("ghc.core.lsp.common").on_attach
local on_init = require("ghc.core.lsp.common").on_init
local capabilities = require("ghc.core.lsp.common").capabilities

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    eslint = {
      root_dir = function(filename)
        local util = require("lspconfig.util")
        return util.root_pattern(".git")(filename) or util.root_pattern("package.json", "tsconfig.json", "jsconfig.json")(filename)
      end,
    },
  },
}
