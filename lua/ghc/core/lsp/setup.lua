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

vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
  border = "single",
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
  border = "single",
  focusable = false,
  relative = "cursor",
  silent = true,
})

local setup = {
  function(server_name)
    require("lspconfig")[server_name].setup({})
  end,
  clangd = function()
    require("lspconfig").clangd.setup(require("ghc.core.lsp.lang.cpp"))
  end,
  eslint = function()
    require("lspconfig").clangd.setup(require("ghc.core.lsp.lang.eslint"))
  end,
  html = function()
    require("lspconfig").html.setup(require("ghc.core.lsp.lang.html"))
  end,
  jsonls = function()
    require("lspconfig").jsonls.setup(require("ghc.core.lsp.lang.json"))
  end,
  lua_ls = function()
    require("lspconfig").lua_ls.setup(require("ghc.core.lsp.lang.lua"))
  end,
  pyright = function()
    require("lspconfig").pyright.setup(require("ghc.core.lsp.lang.python"))
  end,
  tsserver = function()
    require("lspconfig").tsserver.setup(require("ghc.core.lsp.lang.typescript"))
  end,
}

return setup