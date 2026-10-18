-- https://github.com/neovim/nvim-lspconfig/blob/34229c6e021f8d2b9c947222ccd03605040b81b5/lsp/lua_ls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = {
    ".emmyrc.json",
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    ".stylua.toml",
    "stylua.toml",
    "selene.toml",
    "selene.yml",
    ".git",
  },
  settings = {
    Lua = {
      codeLens = {
        enable = true,
      },
      completion = {
        callSnippet = "Replace",
        showWord = "Disable",
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
        path = { "lua/?.lua", "lua/?/init.lua" },
        pathStrict = true,
        version = "LuaJIT",
      },
      workspace = {
        checkThirdParty = false,
        library = {
          dot.path.join(vim.env.VIMRUNTIME, "lua"),
          "${3rd}/luv/library",
        },
      },
    },
  },
  on_attach = era.m.lsp.event.on_attach,
}
