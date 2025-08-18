-- https://github.com/neovim/nvim-lspconfig/blob/5b646bf2d04a8e93ecef23d38442546b079577d4/lsp/cssls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#cssls

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local workspace = std.path.workspace() ---@type string
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if #filepath > #workspace and filepath:sub(1, #workspace) == workspace then
    on_dir(workspace)
    return
  end
end

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
  client.server_capabilities.documentFormattingProvider = true
end

return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = { "vscode-css-language-server", "--stdio" },
  filetypes = { "css", "scss", "less" },
  init_options = {
    provideFormatter = true,
  },
  settings = {
    css = { validate = true },
    less = { validate = true },
    scss = { validate = true },
  },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
