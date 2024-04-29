local function config(_, opts)
  dofile(vim.g.base46_cache .. "mason")
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
      "taplo", -- toml
      "tsserver", -- javascript/typescript
      "vuels", -- vue -- by vuejs official
      "yamlls", -- yaml -- by redhat
    },
    automatic_installation = false,
    handlers = require("ghc.core.lsp.setup"),
  })

  -- custom nvchad cmd to install all mason binaries listed
  vim.api.nvim_create_user_command("MasonInstallAll", function()
    if opts.ensure_installed and #opts.ensure_installed > 0 then
      vim.cmd("MasonInstall " .. table.concat(opts.ensure_installed, " "))
    end
  end, {})
end

return config
