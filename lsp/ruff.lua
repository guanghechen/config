-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/ruff.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ruff

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)

  client.server_capabilities.hoverProvider = false
  client.server_capabilities.completionProvider = nil

  ---@type stl.t.IKeymap[]
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
  era.m.lsp.event.bindkeys(client, bufnr, keymaps)
end

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "ruff", "server" },
  filetypes = { "python" },
  init_options = {
    settings = {
      logLevel = "error",
    },
  },
  root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
  settings = {},
  on_attach = on_attach,
}
