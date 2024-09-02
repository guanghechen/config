---@type string[]
local ensure_installed = {
  -- lsp
  "bash-language-server", -- bashls
  "clangd", -- clangd
  "css-lsp", -- cssls
  "dockerfile-language-server", -- docker
  "docker-compose-language-service", -- docker_compose_language_service
  "eslint-lsp", -- eslint
  "html-lsp", -- html
  "json-lsp", -- jsonls
  "lua-language-server", -- lua_ls
  "pyright", -- pyright
  "rust-analyzer", -- rust_analyzer
  -- "sqls", -- sqls
  "tailwindcss-language-server", --  tailwindcss
  "taplo", -- taplo
  "typescript-language-server", -- tsserver
  "vetur-vls", -- vuels
  "yaml-language-server", -- yamlls

  -- formatter
  "codespell",
  "prettier",
  "shfmt",
  "stylua",
}

---@return nil
local function install_all()
  vim.cmd("Mason")
  local mr = require("mason-registry")
  for _, pkgName in ipairs(ensure_installed) do
    local p = mr.get_package(pkgName)
    if not p:is_installed() then
      p:install()
    end
  end
end

---@return nil
local function install_all_force()
  vim.cmd("Mason")
  local mr = require("mason-registry")
  for _, pkgName in ipairs(ensure_installed) do
    local p = mr.get_package(pkgName)
    p:install()
  end
end

return {
  name = "mason.nvim",
  cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonInstallAllForce", "MasonUpdate" },
  build = function()
    vim.defer_fn(function()
      vim.cmd("MasonUpdate")
      install_all()
    end, 1000)
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
    require("mason").setup(opts)
    require("mason-lspconfig").setup({
      ensure_installed = {
        "bashls", -- bash
        "clangd", -- c/c++
        "cssls", -- css -- by microsoft
        "dockerls", -- docker
        "docker_compose_language_service", --docker compose -- by microsoft
        "eslint", -- eslint -- by microsoft
        "html", -- html -- by microsoft
        "jsonls", -- json
        "lua_ls", -- lua
        "pyright", -- python -- by microsoft
        "rust_analyzer", -- rust -- by rust official
        -- "sqls", -- sql
        "tailwindcss",
        "taplo", -- toml
        "tsserver", -- javascript/typescript
        "vuels", -- vue -- by vuejs official
        "yamlls", -- yaml -- by redhat
      },
      automatic_installation = false,
      handlers = require("guanghechen.lsp.setup"),
    })

    -- custom cmd to install all mason binaries listed
    vim.api.nvim_create_user_command("MasonInstallAll", install_all, {})
    vim.api.nvim_create_user_command("MasonInstallAllForce", install_all_force, {})
  end,
  dependencies = {
    "mason-lspconfig.nvim",
  },
}
