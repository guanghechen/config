-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/lua_ls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  dot.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  dot.lsp.event.on_attach(client, bufnr)
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
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  log_level = vim.lsp.protocol.MessageType.Warning,
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    ".stylua.toml",
    "stylua.toml",
    ".git",
  },
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
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
