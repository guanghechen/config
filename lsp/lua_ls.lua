-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/lua_ls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls

local nvim_config = nil ---@type string|nil
local workspace = dot.path.workspace() ---@type string
if workspace == dot.path.locate_app_config_home("nvim") then
  nvim_config = dot.path.join(workspace, "lua")
elseif workspace == dot.path.locate_app_config_home("nvim-nvchad") then
  nvim_config = dot.path.join(workspace, "lua")
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  dot.lsp.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  dot.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  dot.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  dot.lsp.on_init(client, config)
end

---@type vim.lsp.Config
return {
  capabilities = dot.lsp.get_capabilities(),
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
        library = vim.tbl_filter(ark.fn.boolean, {
          dot.path.join(vim.env.VIMRUNTIME, "lua"),
          dot.path.join(ark.env.HOME_NVIM_DATA, "lazy/lazy.nvim"),
          nvim_config,
          "${3rd}/luv/library",
        }),
      },
    },
  },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
