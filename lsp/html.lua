-- https://github.com/neovim/nvim-lspconfig/blob/ff18d1256877361113edc2970a2c367043d6414c/lsp/html.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#html

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "vscode-html-language-server", "--stdio" },
  filetypes = { "html", "templ" },
  flags = {
    debounce_text_changes = 500,
    exit_timeout = 200,
  },
  root_markers = { "package.json", ".git" },
  init_options = {
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { "html", "css", "javascript" },
    provideFormatter = true,
  },
  single_file_support = true,
  settings = {},
  on_attach = era.m.lsp.event.on_attach,
  on_detach = era.m.lsp.event.on_detach,
}
