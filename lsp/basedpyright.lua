-- https://github.com/neovim/nvim-lspconfig/blob/a1d25809c5f732756cbc06a995e1426b956cdad9/lsp/basedpyright.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#basedpyright

local Methods = vim.lsp.protocol.Methods

---@param command                       {args: string}
---@return nil
local function set_python_path(command)
  local pythonPath = command.args ---@type string
  local clients = vim.lsp.get_clients({
    bufnr = vim.api.nvim_get_current_buf(),
    name = "basedpyright",
  })
  for _, client in ipairs(clients) do
    local settings = client.config.settings or {}
    settings.python = settings.python or {}
    ---@diagnostic disable-next-line: inject-field
    settings.python.pythonPath = pythonPath
    client.config.settings = settings
    client.settings = settings
    client:notify(Methods.workspace_didChangeConfiguration, { settings = settings })
  end
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  era.m.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)

  vim.api.nvim_buf_create_user_command(bufnr, "LspPyrightOrganizeImports", function()
    local params = {
      title = "basedpyright.organizeimports",
      command = "basedpyright.organizeimports",
      arguments = { vim.uri_from_bufnr(bufnr) },
    }

    -- Using client.request() directly because "basedpyright.organizeimports" is private
    -- (not advertised via capabilities), which client:exec_cmd() refuses to call.
    -- https://github.com/neovim/neovim/blob/c333d64663d3b6e0dd9aa440e433d346af4a3d81/runtime/lua/vim/lsp/client.lua#L1024-L1030
    client:request("workspace/executeCommand", params, nil, bufnr)
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
  cmd = { "basedpyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = {
    "pyrightconfig.json",
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    ".git",
  },
  settings = {
    basedpyright = {
      analysis = {
        autoSearchPaths = true,
        diagnosticMode = "openFilesOnly",
        -- https://docs.basedpyright.com/latest/configuration/language-server-settings/
        -- Explicitly setting `basedpyright.analysis.useLibraryCodeForTypes` is **discouraged** by the official docs.
        -- Because it will override per-project configurations like `pyproject.toml`.
        -- If left unset, its default value is `true`, and it can be correctly overridden by project config files.
      },
      disableTaggedHints = true,
    },
  },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
