local opts = {
  ensure_installed = {
    -- lsp
    "bash-language-server", -- bashls
    "clangd", -- clangd
    "css-lsp", -- cssls
    "dockerfile-language-server", -- docker
    "docker-compose-language-service", -- docker_compose_language_service
    "eslint-lsp", -- eslint
    "html-lsp", -- html
    "java-language-server", -- java
    "json-lsp", -- jsonls
    "lua-language-server", -- lua_ls
    "pyright", -- pyright
    "rust-analyzer", -- rust_analyzer
    "sqls", -- sqls
    "taplo", -- taplo
    "typescript-language-server", -- tsserver
    "vetur-vls", -- vuels
    'yaml-language-server', -- yamlls

    -- formatter
    "prettier",
    "shfmt",
    "stylua",
  },
  PATH = "skip", -- don't modify PATH
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
}

return opts
