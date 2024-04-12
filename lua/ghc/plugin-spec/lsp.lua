return {
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
