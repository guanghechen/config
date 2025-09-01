-- https://github.com/neovim/nvim-lspconfig/blob/f4dee350521da3b95fffdfdb94f7a1b5cdb88d79/lsp/basedpyright.lua
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
    client.settings = client.settings or {}
    client.settings.python = client.settings.python or {}
    client.settings.python["pythonPath"] = pythonPath
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
  eve.lsp.on_detach(client, bufnr)
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
  on_detach = on_detach,
  on_init = on_init,
}
