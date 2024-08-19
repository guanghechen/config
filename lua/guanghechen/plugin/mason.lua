return {
  url = "https://github.com/guanghechen/mirror.git",
  branch = "nvim@mason.nvim",
  name = "mason.nvim",
  main = "mason",
  cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },
  build = ":MasonUpdate",
  opts = {
    ensure_installed = {
      -- lsp
      "bash-language-server",            -- bashls
      "clangd",                          -- clangd
      "codespell",
      "css-lsp",                         -- cssls
      "dockerfile-language-server",      -- docker
      "docker-compose-language-service", -- docker_compose_language_service
      "eslint-lsp",                      -- eslint
      "html-lsp",                        -- html
      "json-lsp",                        -- jsonls
      "lua-language-server",             -- lua_ls
      "pyright",                         -- pyright
      "rust-analyzer",                   -- rust_analyzer
      -- "sqls", -- sqls
      "tailwindcss-language-server",     --  tailwindcss
      "taplo",                           -- taplo
      "typescript-language-server",      -- tsserver
      "vetur-vls",                       -- vuels
      "yaml-language-server",            -- yamlls

      -- formatter
      "prettier",
      "shfmt",
      "stylua",
    },
    PATH = "prepend",
    log_level = vim.log.levels.INFO,
    max_concurrent_installers = 10,
    ui = {
      check_outdated_packages_on_open = false,
      icons = {
        package_pending = " ",
        package_installed = "󰄳 ",
        package_uninstalled = " 󰚌",
      },
      keymaps = {
        toggle_help = "g?",
        toggle_package_install_log = "<CR>",
        toggle_server_expand = "<CR>",
        install_server = "i",
        update_server = "u",
        check_server_version = "c",
        update_all_servers = "U",
        check_outdated_servers = "C",
        uninstall_server = "X",
        cancel_installation = "<C-c>",
      },
    },
  },
  config = function(_, opts)
    require("mason").setup(opts)
    require("mason-lspconfig").setup({
      ensure_installed = {
        "bashls",                          -- bash
        "clangd",                          -- c/c++
        "cssls",                           -- css -- by microsoft
        "dockerls",                        -- docker
        "docker_compose_language_service", --docker compose -- by microsoft
        "eslint",                          -- eslint -- by microsoft
        "html",                            -- html -- by microsoft
        "jsonls",                          -- json
        "lua_ls",                          -- lua
        "pyright",                         -- python -- by microsoft
        "rust_analyzer",                   -- rust -- by rust official
        -- "sqls", -- sql
        "tailwindcss",
        "taplo",    -- toml
        "tsserver", -- javascript/typescript
        "vuels",    -- vue -- by vuejs official
        "yamlls",   -- yaml -- by redhat
      },
      automatic_installation = false,
      handlers = require("guanghechen.lsp.setup"),
    })

    -- custom cmd to install all mason binaries listed
    vim.api.nvim_create_user_command("MasonInstallAll", function()
      if opts.ensure_installed and #opts.ensure_installed > 0 then
        vim.cmd("MasonInstall " .. table.concat(opts.ensure_installed, " "))
      end
    end, {})
  end,
  dependencies = {
    "mason-lspconfig.nvim",
  },
}
