-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/taplo.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#taplo

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "taplo", "lsp", "stdio" },
  filetypes = { "toml" },
  root_markers = { ".taplo.toml", "taplo.toml", ".git" },
  on_attach = era.m.lsp.event.on_attach,
  on_detach = era.m.lsp.event.on_detach,
}
