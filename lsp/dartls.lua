-- https://github.com/neovim/nvim-lspconfig/blob/master/lsp/dartls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#dartls

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "dart", "language-server", "--protocol=lsp" },
  filetypes = { "dart" },
  root_markers = {
    "pubspec.yaml",
    ".git",
  },
  init_options = {
    -- Deprecated upstream (default false): re-analyzes roots on every open/close and
    -- can block requests, delaying the first definition/semantic-token response.
    onlyAnalyzeProjectsWithOpenFiles = false,
    suggestFromUnimportedLibraries = true,
    closingLabels = false,
    outline = false,
    flutterOutline = false,
  },
  settings = {
    dart = {
      completeFunctionCalls = true,
      documentation = "full",
      enableSnippets = true,
      lineLength = 80,
      showTodos = true,
      updateImportsOnRename = true,
    },
  },
  on_attach = era.m.lsp.event.on_attach,
}
