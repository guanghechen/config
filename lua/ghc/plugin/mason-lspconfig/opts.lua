-- https://mason-registry.dev/registry/list
-- https://github.com/williamboman/mason-lspconfig.nvim/blob/main/doc/server-mapping.md

local opts = {
  ensure_installed = {
    "bashls", -- bash
    "clangd", -- c/c++
    "cssls",  -- css -- by microsoft
    "dockerls", -- docker
    "docker_compose_language_service", --docker compose -- by microsoft
    "eslint", -- eslint -- by microsoft
    "html",   -- html -- by microsoft
    "java_language_server", -- java
    "jsonls", -- json
    "lua_ls", -- lua
    "pyright", -- python -- by microsoft
    "rust_analyzer", -- rust -- by rust official
    "sqls", -- sql
    "taplo", -- toml
    "tsserver", -- javascript/typescript
    "vuels", -- vue -- by vuejs official
    "yamlls", -- yaml -- by redhat
  },
  automatic_installation = false,
  handlers = nil,
}

return opts
