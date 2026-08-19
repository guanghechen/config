---@see https://github.com/mason-org/mason.nvim

local __module_name__ = "era.plugin.mason" ---@type string

----------------------------------------------------------------------------------------------------

---@return string[]
local function get_mason_ensure_installed()
  return {
    -- lsp --
    "bash-language-server", -- bashls
    -- "clangd", -- clangd
    "css-lsp", -- cssls
    "dockerfile-language-server", -- docker
    "emmet-language-server", -- emmet_language_server
    "docker-compose-language-service", -- docker_compose_language_service
    "eslint-lsp", -- eslint
    "html-lsp", -- html
    "json-lsp", -- jsonls
    "lua-language-server", -- lua_ls
    -- "pyright", -- pyright
    "basedpyright", -- basedpyright
    "roslyn-language-server", -- roslyn_ls
    "rust-analyzer", -- rust_analyzer
    -- "sqls", -- sqls
    "svelte-language-server", -- svelte
    "tailwindcss-language-server", --  tailwindcss
    "taplo", -- taplo
    "vtsls", -- vtsls
    "yaml-language-server", -- yamlls

    -- dap --
    "debugpy",
    "js-debug-adapter",

    -- lint --
    "cspell",
    "ruff",
    "shellcheck",

    -- formatter --
    "black",
    "isort",
    "prettier",
    "shfmt",
    "stylelint",
    "stylua",

    -- utilities --
    -- "tree-sitter-cli",
  }
end

---@param packages                      string[]
---@param force                         boolean
---@param on_close                      fun(): nil
local function do_install(packages, force, on_close)
  local mr = require("mason-registry")
  local to_install = {} ---@type string[]
  local invalid_packages = {} ---@type string[]

  for _, pkg_name in ipairs(packages) do
    if not mr.has_package(pkg_name) then
      table.insert(invalid_packages, pkg_name)
    elseif force then
      table.insert(to_install, pkg_name)
    else
      local p = mr.get_package(pkg_name)
      if not p:is_installed() then
        table.insert(to_install, pkg_name)
      end
    end
  end

  if #invalid_packages > 0 then
    stl.reporter.error({
      from = __module_name__,
      subject = "Invalid packages",
      message = "The following packages do not exist in mason registry",
      details = invalid_packages,
    })
  end

  local count = #to_install
  if count < 1 then
    on_close()
    return
  end

  local install_failed = {} ---@type string[]
  for _, pkg_name in ipairs(to_install) do
    local p = mr.get_package(pkg_name)
    local handle = p:install()
    handle:once("closed", function()
      if not p:is_installed() then
        table.insert(install_failed, pkg_name)
      end
      count = count - 1
      if count < 1 then
        if #install_failed > 0 then
          stl.reporter.error({
            from = __module_name__,
            subject = "Installation failed",
            message = "The following packages failed to install",
            details = install_failed,
          })
        end
        on_close()
      end
    end)
  end
end

---@param packages                      string[]
---@param force                         boolean
---@param on_close                      fun(): nil
local function action_install(packages, force, on_close)
  local mr = require("mason-registry")
  mr.refresh(function()
    do_install(packages, force, on_close)
  end)
end

---@param force                         boolean
---@param on_close                      fun(): nil
local function action_install_all(force, on_close)
  require("mason.ui").open()
  local packages = get_mason_ensure_installed() ---@type string[]
  action_install(packages, force, on_close)
end

----------------------------------------------------------------------------------------------------

---@class era.plugin.mason
---@field public get_mason_ensure_installed fun(): string[]
---@field public install                fun(packages: string[], force: boolean, on_close: fun(): nil): nil
---@field public install_all            fun(force: boolean, on_close: fun(): nil): nil
local M = {
  get_mason_ensure_installed = get_mason_ensure_installed,
  install = action_install,
  install_all = action_install_all,
}

----------------------------------------------------------------------------------------------------

---@type era.m.plugin.IPluginSpec
M.spec = {
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
    require("mason").setup(opts)

    vim.api.nvim_create_user_command("MasonInstallAll", function()
      M.install_all(false, stl.fn.noop)
    end, {})
    vim.api.nvim_create_user_command("MasonInstallAllForce", function()
      M.install_all(true, stl.fn.noop)
    end, {})
  end,
}

return M
