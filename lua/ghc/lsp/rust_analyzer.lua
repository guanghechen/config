local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_attach = eve.lsp.on_attach,
  on_init = eve.lsp.on_init,
  settings = {
    ["rust-analyzer"] = {
      check = {
        command = "clippy",
      },
      completion = {
        limit = 69,
        privateEditable = {
          enable = true,
        },
      },
      imports = {
        merge = {
          blob = false,
        },
      },
      procMacro = {
        enable = true,
      },
    },
  },
}
