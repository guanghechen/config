-- https://github.com/neovim/nvim-lspconfig/blob/030a72f0aa4d56f9e8ff67921e6e3ffd0e97bf07/lsp/docker_compose_language_service.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#docker_compose_language_service

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "docker-compose-langserver", "--stdio" },
  filetypes = { "yaml.docker-compose" },
  root_markers = { "docker-compose.yaml", "docker-compose.yml", "compose.yaml", "compose.yml" },
  on_attach = era.m.lsp.event.on_attach,
  on_detach = era.m.lsp.event.on_detach,
}
