-- https://github.com/neovim/nvim-lspconfig/blob/4d3b3bb8815fbe37bcaf3dbdb12a22382bc11ebe/doc/configs.md#basedpyright

local Methods = vim.lsp.protocol.Methods

---@param path                          string
---@return nil
local function set_python_path(path)
  local clients = vim.lsp.get_clients({
    bufnr = vim.api.nvim_get_current_buf(),
    name = "basedpyright",
  })
  for _, client in ipairs(clients) do
    client.settings = client.settings or {}
    client.settings.python = client.settings.python or {}
    client.settings.python["pythonPath"] = path
    client:notify(Methods.workspace_didChangeConfiguration, { settings = nil })
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

  vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightOrganizeImports", function()
    client:exec_cmd({
      title = "basedpyright.organizeimports",
      command = "basedpyright.organizeimports",
      arguments = { vim.uri_from_bufnr(bufnr) },
    })
  end, {
    desc = "Organize Imports",
  })

  vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightSetPythonPath", set_python_path, {
    desc = "Reconfigure basedpyright with the provided python path",
    nargs = 1,
    complete = "file",
  })
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "pyrightconfig.json",
    ".git",
  },
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
      },
    },
  },
  before_init = before_init,
  on_attach = on_attach,
  on_init = on_init,
}
