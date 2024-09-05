local register_capability = vim.lsp.handlers["client/registerCapability"]
vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
  ---@diagnostic disable-next-line: no-unknown
  local ret = register_capability(err, res, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  local buffer = vim.api.nvim_get_current_buf()
  if client then
    vim.api.nvim_exec_autocmds("User", {
      pattern = "LspDynamicCapability",
      data = { client_id = client.id, buffer = buffer },
    })
  end
  return ret
end

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  focusable = false,
})

local setup = {
  function(server_name)
    require("lspconfig")[server_name].setup({})
  end,
  clangd = function()
    require("lspconfig").clangd.setup(require("guanghechen.lsp.lang.cpp"))
  end,
  eslint = function()
    require("lspconfig").eslint.setup(require("guanghechen.lsp.lang.eslint"))
  end,
  html = function()
    require("lspconfig").html.setup(require("guanghechen.lsp.lang.html"))
  end,
  jsonls = function()
    require("lspconfig").jsonls.setup(require("guanghechen.lsp.lang.json"))
  end,
  lua_ls = function()
    require("lspconfig").lua_ls.setup(require("guanghechen.lsp.lang.lua"))
  end,
  pyright = function()
    require("lspconfig").pyright.setup(require("guanghechen.lsp.lang.python"))
  end,
  rust_analyzer = function()
    require("lspconfig").rust_analyzer.setup(require("guanghechen.lsp.lang.rust"))
  end,
  tailwindcss = function()
    require("lspconfig").tailwindcss.setup(require("guanghechen.lsp.lang.tailwindcss"))
  end,
  ---TODO should replace it with ts_ls when mason applied the changes, see https://github.com/neovim/nvim-lspconfig/pull/3232#issuecomment-2331025714
  tsserver = function()
    require("lspconfig").ts_ls.setup(require("guanghechen.lsp.lang.typescript"))
  end,
}

return setup
