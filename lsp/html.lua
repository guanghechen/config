-- https://github.com/neovim/nvim-lspconfig/blob/5b646bf2d04a8e93ecef23d38442546b079577d4/lsp/html.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#html

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  eve.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = { "vscode-html-language-server", "--stdio" },
  filetypes = { "html", "templ" },
  flags = { debounce_text_changes = 500 },
  root_markers = { "package.json", ".git" },
  init_options = {
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { "html", "css", "javascript" },
    provideFormatter = true,
  },
  single_file_support = true,
  settings = {},
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
