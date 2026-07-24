-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/jsonls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#jsonls

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  era.m.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  era.m.lsp.event.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  era.m.lsp.event.on_init(client, config)
end

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
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
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
