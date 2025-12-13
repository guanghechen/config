-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/html.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#html

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  era.lsp.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  era.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  era.lsp.on_init(client, config)
end

---@type vim.lsp.Config
return {
  capabilities = era.lsp.get_capabilities(),
  cmd = { "vscode-html-language-server", "--stdio" },
  filetypes = { "html", "templ" },
  flags = {
    debounce_text_changes = 500,
    exit_timeout = 200,
  },
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
