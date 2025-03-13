local fn = require("eve.builtin.fn")

return {
  name = "mason.nvim",
  cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonInstallAllForce", "MasonUpdate" },
  build = ":MasonUpdate",
  opts = {
    PATH = "prepend",
    log_level = vim.log.levels.INFO,
    max_concurrent_installers = 10,
    ui = {
      check_outdated_packages_on_open = false,
      icons = {
        package_pending = " ",
        package_installed = " ",
        package_uninstalled = " ",
      },
    },
  },
  config = function(_, opts)
    local action = require("ghc.action.mason")
    local handlers = require("ghc.lsp.setup")

    -- custom cmd to install all mason binaries listed
    vim.api.nvim_create_user_command("MasonInstallAll", function()
      action.install_all(false, eve.std.fn.noop)
    end, {})
    vim.api.nvim_create_user_command("MasonInstallAllForce", function()
      action.install_all(true, eve.std.fn.noop)
    end, {})

    require("mason").setup(opts)

    local ensure_installed = action.get_mason_lspconfig_ensure_installed() ---@type string[]
    require("mason-lspconfig").setup({
      ensure_installed = ensure_installed,
      automatic_installation = false,
      handlers = handlers,
    })
  end,
  dependencies = {
    "mason-lspconfig.nvim",
  },
}
