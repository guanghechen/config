local on_attach = require("ghc.core.lsp.common").on_attach
local on_init = require("ghc.core.lsp.common").on_init
local capabilities = require("ghc.core.lsp.common").capabilities

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    tsserver = {
      completions = {
        completeFunctionCalls = true,
      },
      root_dir = function(filename)
        local util = require("lspconfig.util")
        return util.root_pattern(".git")(filename) or util.root_pattern("package.json", "tsconfig.json", "jsconfig.json")(filename)
      end,
      typescript = {
        inlayHints = {
          includeInlayParameterNameHints = "literal",
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = false,
          includeInlayVariableTypeHints = false,
          includeInlayPropertyDeclarationTypeHints = false,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
      },
      javascript = {
        inlayHints = {
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = false,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
        },
      },
    },
  },
}
