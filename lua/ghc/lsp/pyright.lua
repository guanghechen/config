local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_attach = eve.lsp.on_attach,
  on_init = eve.lsp.on_init,
  settings = {
    python = {
      enabled = true,
      pythonPath = eve.context.lsp.get_python_bin_path(),
      analysis = {
        typeCheckingMode = "standard",
        autoImportCompletions = true,
        diagnosticMode = "openFilesOnly",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        indexing = true,
      },
    },
  },
}
