-- https://github.com/neovim/nvim-lspconfig/blob/5b646bf2d04a8e93ecef23d38442546b079577d4/lsp/docker_compose_language_service.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#docker_compose_language_service

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  eve.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = { "docker-compose-langserver", "--stdio" },
  filetypes = { "yaml.docker-compose" },
  root_markers = { "docker-compose.yaml", "docker-compose.yml", "compose.yaml", "compose.yml" },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
