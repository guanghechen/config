-- https://github.com/neovim/nvim-lspconfig/blob/4d3b3bb8815fbe37bcaf3dbdb12a22382bc11ebe/doc/configs.md#jsonls

local capabilities = eve.lsp.get_capabilities()

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

return {
  capabilities = capabilities,
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc", "excalidraw" },
  init_options = {
    provideFormatter = true,
  },
  root_markers = { ".git" },
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
  on_attach = on_attach,
  on_init = on_init,
}
