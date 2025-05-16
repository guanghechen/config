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
      doc = {
        privateName = { "^_" },
      },
      diagnostics = {
        disable = { "different-requires" },
        globals = { "vim" },
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
        path = { "?.lua", "?/init.lua" },
        pathStrict = true,
        version = "LuaJIT",
      },
      workspace = {
        checkThirdParty = false,
        library = {
          eve.path.join(vim.env.VIMRUNTIME, "lua"),
          eve.path.join(std.env.HOME_NVIM_DATA, "lazy/lazy.nvim"),
          eve.path.join(std.env.HOME_NVIM_CONFIG, "lua"),
          "${3rd}/luv/library",
        },
      },
    },
  },
}
