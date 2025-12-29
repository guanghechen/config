-- https://github.com/neovim/nvim-lspconfig/blob/1b590dc980178611b4d8f1f13daf7f23dc878294/lsp/docker_compose_language_service.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#docker_compose_language_service

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  era.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.lsp.event.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  era.lsp.event.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  era.lsp.event.on_init(client, config)
end

---@type vim.lsp.Config
return {
  capabilities = era.lsp.event.get_capabilities(),
  cmd = { "docker-compose-langserver", "--stdio" },
  filetypes = { "yaml.docker-compose" },
  root_markers = { "docker-compose.yaml", "docker-compose.yml", "compose.yaml", "compose.yml" },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
