-- https://github.com/neovim/nvim-lspconfig/blob/ff18d1256877361113edc2970a2c367043d6414c/lsp/html.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#html

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  era.m.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  era.m.lsp.event.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  era.m.lsp.event.on_init(client, config)
end

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "vscode-html-language-server", "--stdio" },
  filetypes = { "html" },
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
