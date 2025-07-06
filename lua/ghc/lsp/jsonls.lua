-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#jsonls

local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_attach = eve.lsp.on_attach,
  on_init = eve.lsp.on_init,
  flags = { debounce_text_changes = 500 },
  settings = {
    json = {
      format = {
        enable = true,
      },
      schemas = {
        {
          description = "ESLint configuration files",
          fileMatch = { ".eslintrc", ".eslintrc.json", ".eslintrc.yml", ".eslintrc.yaml" },
          name = ".eslintrc",
          url = "https://www.schemastore.org/eslintrc.json",
        },
        {
          description = "NPM configuration file",
          fileMatch = { "package.json" },
          name = "package.json",
          url = "https://www.schemastore.org/package.json",
        },
      },
      suggest = {
        json5 = true,
      },
      validate = {
        enable = true,
      },
    },
  },
}
