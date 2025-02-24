-- https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/server_configurations/jsonls.lua

local get_capabilities = require("ghc.lsp.common").get_capabilities
local handlers = require("ghc.lsp.common").handlers
local on_attach = require("ghc.lsp.common").on_attach
local on_init = require("ghc.lsp.common").on_init

return function()
  local capabilities = get_capabilities()

  -- lazy-load schemastore when needed
  local on_new_config = function(new_config)
    new_config.settings.json.schemas = new_config.settings.json.schemas or {}
    vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
  end

  return {
    capabilities = capabilities,
    handlers = handlers,
    on_attach = on_attach,
    on_init = on_init,
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
end
