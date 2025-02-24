local get_capabilities = require("ghc.lsp.common").get_capabilities
local handlers = require("ghc.lsp.common").handlers
local on_attach = require("ghc.lsp.common").on_attach
local on_init = require("ghc.lsp.common").on_init

return function()
  local capabilities = get_capabilities()
  capabilities.textDocument = capabilities.textDocument or {}
  capabilities.textDocument.foldingRange = capabilities.textDocument.foldingRange or {}
  capabilities.textDocument.foldingRange.dynamicRegistration = false
  capabilities.textDocument.foldingRange.lineFoldingOnly = true

  -- lazy-load schemastore when needed
  local function on_new_config(new_config)
    new_config.settings.yaml.schemas =
      vim.tbl_deep_extend("force", new_config.settings.yaml.schemas or {}, require("schemastore").yaml.schemas())
  end

  return {
    capabilities = capabilities,
    handlers = handlers,
    on_attach = on_attach,
    on_init = on_init,
    on_new_config = on_new_config,
    settings = {
      redhat = { telemetry = { enabled = false } },
      yaml = {
        keyOrdering = false,
        format = {
          enable = true,
        },
        validate = true,
        schemaStore = {
          -- Must disable built-in schemaStore support to use
          -- schemas from SchemaStore.nvim plugin
          enable = false,
          -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
          url = "",
        },
      },
    },
  }
end
