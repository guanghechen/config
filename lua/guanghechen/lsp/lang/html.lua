-- https://github.com/vscode-langservers/vscode-html-languageserver-bin

local get_capabilities = require("guanghechen.lsp.common").get_capabilities
local handlers = require("guanghechen.lsp.common").handlers
local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init

return function()
  local capabilities = get_capabilities()

  return {
    capabilities = capabilities,
    handlers = handlers,
    on_attach = on_attach,
    on_init = on_init,
    cmd = { "html-languageserver", "--stdio" },
    filetypes = { "html" },
    init_options = {
      configurationSection = { "html", "css", "javascript" },
      embeddedLanguages = { css = true, javascript = true },
    },
    settings = {},
    single_file_support = true,
    flags = { debounce_text_changes = 500 },
  }
end
