---@see https://github.com/mason-org/mason.nvim/tree/57e5a8addb8c71fb063ee4acda466c7cf6ad2800

return {
  name = "mason.nvim",
  cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonInstallAllForce", "MasonUpdate" },
  build = ":MasonUpdate",
  opts = {
    PATH = "skip",
    log_level = vim.log.levels.INFO,
    max_concurrent_installers = 10,
    ui = {
      backdrop = 60,
      border = "none",
      check_outdated_packages_on_open = true,
      icons = {
        package_pending = " ",
        package_installed = " ",
        package_uninstalled = " ",
      },
    },
  },
  config = function(_, opts)
    local action = require("fml.action.plugin.mason")
    require("mason").setup(opts)

    -- custom cmd to install all mason binaries listed
    vim.api.nvim_create_user_command("MasonInstallAll", function()
      action.install_all(false, stl.fn.noop)
    end, {})
    vim.api.nvim_create_user_command("MasonInstallAllForce", function()
      action.install_all(true, stl.fn.noop)
    end, {})
  end,
}
