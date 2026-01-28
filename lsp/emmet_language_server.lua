-- https://github.com/neovim/nvim-lspconfig/blob/ff18d1256877361113edc2970a2c367043d6414c/lsp/emmet_language_server.lua
-- https://github.com/olrtg/emmet-language-server

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
  cmd = { "emmet-language-server", "--stdio" },
  filetypes = {
    "astro",
    "css",
    "eruby",
    "html",
    "htmlangular",
    "htmldjango",
    "javascriptreact",
    "less",
    "sass",
    "scss",
    "svelte",
    "typescriptreact",
    "vue",
  },
  root_markers = { ".git" },
  single_file_support = true,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
