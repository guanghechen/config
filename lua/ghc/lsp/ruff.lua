-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ruff

local function on_attach(client, bufnr)
  client.server_capabilities.hoverProvider = false
  eve.lsp.on_attach(client, bufnr)

  ---@type std.t.IKeymap[]
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
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr })
end

local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_attach = on_attach,
  on_init = eve.lsp.on_init,
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
}
