-- https://github.com/neovim/nvim-lspconfig/blob/ff18d1256877361113edc2970a2c367043d6414c/lsp/emmet_language_server.lua
-- https://github.com/olrtg/emmet-language-server

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "emmet-language-server", "--stdio" },
  filetypes = {
    "astro",
    "css",
    "eruby",
    "html",
    "htmlangular",
    "htmldjango",
    "javascriptreact",
    "less",
    "sass",
    "scss",
    "svelte",
    "typescriptreact",
  },
  root_markers = { ".git" },
  on_attach = era.m.lsp.event.on_attach,
}
