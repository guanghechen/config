local functional = require("eve.lib.functional")
local action = require("guanghechen.action.mason")
local handlers = require("guanghechen.lsp.setup")

local ensure_installed = action.get_mason_lspconfig_ensure_installed() ---@type string[]

-- custom cmd to install all mason binaries listed
vim.api.nvim_create_user_command("MasonInstallAll", function()
  action.install_all(false, functional.noop)
end, {})
vim.api.nvim_create_user_command("MasonInstallAllForce", function()
  action.install_all(true, functional.noop)
end, {})

return {
  name = "mason-lspconfig.nvim",
  opts = {
    ensure_installed = ensure_installed,
    automatic_installation = false,
    handlers = handlers,
  },
  dependencies = {
    "mason.nvim",
  },
}
