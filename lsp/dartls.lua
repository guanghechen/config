-- https://github.com/neovim/nvim-lspconfig/blob/master/lsp/dartls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#dartls

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
  cmd = { "dart", "language-server", "--protocol=lsp" },
  filetypes = { "dart" },
  log_level = vim.lsp.protocol.MessageType.Warning,
  root_markers = {
    "pubspec.yaml",
    ".git",
  },
  init_options = {
    onlyAnalyzeProjectsWithOpenFiles = true,
    suggestFromUnimportedLibraries = true,
    closingLabels = false,
    outline = false,
    flutterOutline = false,
  },
  settings = {
    dart = {
      completeFunctionCalls = true,
      documentation = "full",
      enableSnippets = true,
      lineLength = 80,
      showTodos = true,
      updateImportsOnRename = true,
    },
  },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
