-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/cssls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#cssls

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "vscode-css-language-server", "--stdio" },
  filetypes = { "css", "scss", "less" },
  init_options = {
    provideFormatter = true,
  },
  root_markers = { "package.json", ".git" },
  settings = {
    css = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
      },
    },
    less = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
      },
    },
    scss = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
      },
    },
  },
  on_attach = era.m.lsp.event.on_attach,
  on_detach = era.m.lsp.event.on_detach,
}
