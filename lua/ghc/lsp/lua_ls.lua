local capabilities = eve.lsp.get_capabilities()

local nvim_config = nil ---@type string|nil
local workspace = std.path.workspace() ---@type string
if workspace == std.path.locate_app_config_home("nvim") then
  nvim_config = std.path.join(workspace, "lua")
elseif workspace == std.path.locate_app_config_home("nvim-nvchad") then
  nvim_config = std.path.join(workspace, "lua")
end

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
        library = vim.tbl_filter(std.fn.boolean, {
          std.path.join(vim.env.VIMRUNTIME, "lua"),
          std.path.join(std.env.HOME_NVIM_DATA, "lazy/lazy.nvim"),
          nvim_config,
          "${3rd}/luv/library",
        }),
      },
    },
  },
}
