-- Upstream reference: https://github.com/neovim/nvim-lspconfig/blob/ac062d0d01c019c0dbdb798968f3e5d8b35c3853/lsp/html.lua
-- Derived from nvim-lspconfig (Apache-2.0); license in lua/era/m/lsp/init.lua.
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#html

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = function(dispatchers, config)
    local command = config.root_dir and era.m.lsp.fn.locate_node_bin(config.root_dir, "vscode-html-language-server")
      or "vscode-html-language-server"
    return vim.lsp.rpc.start({ command, "--stdio" }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = { "html", "templ" },
  flags = {
    debounce_text_changes = 500,
  },
  exit_timeout = 200,
  root_markers = { "package.json", ".git" },
  init_options = {
    embeddedLanguages = { css = true, javascript = true },
    configurationSection = { "html", "css", "javascript" },
    provideFormatter = true,
  },
  settings = {},
  on_attach = era.m.lsp.event.on_attach,
}
