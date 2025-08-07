return {
  name = "mason.nvim",
  cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonInstallAllForce", "MasonUpdate" },
  build = function()
    local action = require("ghc.action.mason")
    action.install_all(false, std.fn.noop)
  end,
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
    require("mason").setup(opts)

    -- custom cmd to install all mason binaries listed
    vim.api.nvim_create_user_command("MasonInstallAll", function()
      action.install_all(false, std.fn.noop)
    end, {})
    vim.api.nvim_create_user_command("MasonInstallAllForce", function()
      action.install_all(true, std.fn.noop)
    end, {})
  end,
}
