local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_attach = eve.lsp.on_attach,
  on_init = eve.lsp.on_init,
  settings = {
    Lua = {
      codeLens = {
        enable = true,
      },
      completion = {
        callSnippet = "Replace",
      },
      diagnostics = {
        disable = { "different-requires" },
        globals = { "vim" },
      },
      doc = {
        privateName = { "^_" },
      },
      format = {
        enable = true,
        defaultConfig = {
          indent_style = "space",
          indent_size = "2",
        },
      },
      hint = {
        enable = true,
        setType = false,
        paramType = true,
        paramName = "Disable",
        semicolon = "Disable",
        arrayIndex = "Disable",
      },
      runtime = {
        version = "LuaJIT",
      },
      semantic = { enable = false },
      telemetry = { enable = false },
      workspace = {
        library = {
          vim.fn.expand("$VIMRUNTIME/lua"),
          vim.fn.expand("$VIMRUNTIME/lua/vim/lsp"),
          vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy",
          "${3rd}/luv/library",
        },
        checkThirdParty = false,
        maxPreload = 100000,
        preloadFileSize = 10000,
      },
    },
  },
}
