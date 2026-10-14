-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/bashls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#bashls

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "bash-language-server", "start" },
  filetypes = { "bash", "sh" },
  root_markers = { ".git" },
  settings = {
    bashIde = {
      globPattern = vim.env.GLOB_PATTERN or "*@(.sh|.inc|.bash|.command)",
    },
  },
  on_attach = era.m.lsp.event.on_attach,
  on_detach = era.m.lsp.event.on_detach,
}
