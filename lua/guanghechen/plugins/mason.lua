local functional = require("eve.lib.functional")
local action = require("guanghechen.action.mason")

-- custom cmd to install all mason binaries listed
vim.api.nvim_create_user_command("MasonInstallAll", function()
  action.install_all(false, functional.noop)
end, {})
vim.api.nvim_create_user_command("MasonInstallAllForce", function()
  action.install_all(true, functional.noop)
end, {})

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
}
