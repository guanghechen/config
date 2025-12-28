-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/ruff.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ruff

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  dot.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  dot.lsp.event.on_attach(client, bufnr)

  client.server_capabilities.hoverProvider = false
  client.server_capabilities.completionProvider = nil

  ---@type ark.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "<leader>co",
      callback = function()
        vim.lsp.buf.code_action({
          apply = true,
          context = {
            only = { "source.organizeImports" },
            diagnostics = {},
          },
        })
      end,
      desc = "Organize Imports",
    },
  }
  ark.vim.fn.bindkeys(keymaps, { bufnr = bufnr })
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  dot.lsp.event.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  dot.lsp.event.on_init(client, config)
end

---@type vim.lsp.Config
return {
  capabilities = dot.lsp.event.get_capabilities(),
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
  settings = {
    ruff = {
      cmd_env = { RUFF_TRACE = "messages" },
      init_options = {
        settings = {
          logLevel = "error",
        },
      },
    },
  },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
