-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#jsonls

local capabilities = eve.lsp.get_capabilities()

-- lazy-load schemastore when needed
local on_new_config = function(new_config)
  new_config.settings.json.schemas = new_config.settings.json.schemas or {}
  vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
end

return {
  capabilities = capabilities,
  on_attach = eve.lsp.on_attach,
  on_init = eve.lsp.on_init,
  on_new_config = on_new_config,
  flags = { debounce_text_changes = 500 },
  settings = {
    json = {
      format = {
        enable = true,
      },
      validate = {
        enable = true,
      },
      suggest = {
        json5 = true,
      },
    },
  },
}
