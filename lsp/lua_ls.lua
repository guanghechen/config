-- https://github.com/neovim/nvim-lspconfig/blob/4d3b3bb8815fbe37bcaf3dbdb12a22382bc11ebe/doc/configs.md#lua_ls

local nvim_config = nil ---@type string|nil
local workspace = std.path.workspace() ---@type string
if workspace == std.path.locate_app_config_home("nvim") then
  nvim_config = std.path.join(workspace, "lua")
elseif workspace == std.path.locate_app_config_home("nvim-nvchad") then
  nvim_config = std.path.join(workspace, "lua")
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  eve.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

return {
  capabilities = eve.lsp.get_capabilities(),
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
        library = vim.tbl_filter(std.fn.boolean, {
          std.path.join(vim.env.VIMRUNTIME, "lua"),
          std.path.join(std.env.HOME_NVIM_DATA, "lazy/lazy.nvim"),
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
