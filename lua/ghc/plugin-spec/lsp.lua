return {
  -- Use Eslint for fix on save and prettier for formatting
  -- https://www.lazyvim.org/configuration/recipes#use-eslint-for-fix-on-save-and-prettier-for-formatting
  { import = "lazyvim.plugins.extras.linting.eslint" },
  { import = "lazyvim.plugins.extras.formatting.prettier" },

  -- Add extra langauges support.
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.json" },

  -- Patch lspconfig
  {
    "neovim/nvim-lspconfig",
    opts = {
      setup = {
        -- Fix clangd offset encoding
        -- https://www.lazyvim.org/configuration/recipes#fix-clangd-offset-encoding
        clangd = function(_, opts)
          opts.capabilities.offsetEncoding = { "utf-16" }
        end,
        -- Add Eslint and use it for formatting
        -- https://www.lazyvim.org/configuration/recipes#add-eslint-and-use-it-for-formatting
        eslint = function()
          require("lazyvim.util").lsp.on_attach(function(client)
            if client.name == "eslint" then
              client.server_capabilities.documentFormattingProvider = true
            elseif client.name == "tsserver" then
              client.server_capabilities.documentFormattingProvider = false
            end
          end)
        end,
      },
    },
  },
}
