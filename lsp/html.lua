-- https://github.com/neovim/nvim-lspconfig/blob/4d3b3bb8815fbe37bcaf3dbdb12a22382bc11ebe/doc/configs.md#html
-- https://github.com/vscode-langservers/vscode-html-languageserver-bin

local capabilities = eve.lsp.get_capabilities()

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

return {
  capabilities = capabilities,
  cmd = { "vscode-html-language-server", "--stdio" },
  filetypes = { "html" },
  flags = { debounce_text_changes = 500 },
  root_markers = { "package.json", ".git" },
  init_options = {
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { "html", "css", "javascript" },
    provideFormatter = true,
  },
  single_file_support = true,
  settings = {},
  on_attach = on_attach,
  on_init = on_init,
}
