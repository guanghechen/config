-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/server_configurations/jsonls.lua

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
    flags = { debounce_text_changes = 500 },
    settings = {
      json = {
        format = {
          enable = true,
        },
        validate = {
          enable = true,
        },
        suggest = {
          json5 = true,
        },
        schemas = {
          {
            fileMatch = { "package.json" },
            url = "https://json.schemastore.org/package.json",
          },
          {
            fileMatch = { "tsconfig*.json" },
            url = "https://json.schemastore.org/tsconfig.json",
          },
          {
            fileMatch = {
              ".prettierrc",
              ".prettierrc.json",
              "prettier.config.json",
            },
            url = "https://json.schemastore.org/prettierrc.json",
          },
          {
            fileMatch = { ".eslintrc", ".eslintrc.json" },
            url = "https://json.schemastore.org/eslintrc.json",
          },
          {
            fileMatch = {
              ".babelrc",
              ".babelrc.json",
              "babel.config.json",
            },
            url = "https://json.schemastore.org/babelrc.json",
          },
          {
            fileMatch = { "lerna.json" },
            url = "https://json.schemastore.org/lerna.json",
          },
          {
            fileMatch = {
              ".stylelintrc",
              ".stylelintrc.json",
              "stylelint.config.json",
            },
            url = "http://json.schemastore.org/stylelintrc.json",
          },
          {
            fileMatch = { "/.github/workflows/*" },
            url = "https://json.schemastore.org/github-workflow.json",
          },
          {
            fileMatch = {
              "*.jsonc",
              "*.json5",
              ".vscode/tasks.json",
              ".vscode/settings.json",
              ".vscode/launch.json",
              ".vscode/extensions.json",
            },
            url = "https://json.schemastore.org/json5",
          },
        },
      },
    },
  }
end
