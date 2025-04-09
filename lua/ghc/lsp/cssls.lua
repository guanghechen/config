-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#cssls

local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_attach = eve.lsp.on_attach,
  on_init = eve.lsp.on_init,
  settings = {
    cssls = {
      css = { validate = true },
      scss = { validate = true },
    },
  },
}
