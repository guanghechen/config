local util_lsp = require("ghc.core.util.lsp")

local function register_lsp_symbol(name, icon)
  local hl = "DiagnosticSign" .. name
  vim.fn.sign_define(hl, { text = icon, numhl = hl, texthl = hl })
end

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  config = function()
    dofile(vim.g.base46_cache .. "lsp")

    register_lsp_symbol("Error", fml.ui.icons.diagnostics.Error)
    register_lsp_symbol("Info", fml.ui.icons.diagnostics.Information)
    register_lsp_symbol("Hint", fml.ui.icons.diagnostics.Hint)
    register_lsp_symbol("Warn", fml.ui.icons.diagnostics.Warning)

    vim.diagnostic.config({
      virtual_text = {
        prefix = "",
      },
      signs = true,
      underline = true,
      -- update_in_insert = false,
      float = {
        border = "single",
      },
    })

    --  LspInfo window borders
    local win = require("lspconfig.ui.windows")
    local _default_opts = win.default_opts
    win.default_opts = function(options)
      local opts = _default_opts(options)
      opts.border = "single"
      return opts
    end

    ---
    if vim.fn.has("nvim-0.10") == 1 then
      -- inlay hints
      ---@diagnostic disable-next-line: unused-local
      util_lsp.on_supports_method("textDocument/inlayHint", function(client, buffer)
        util_lsp.toggle_inlay_hints(buffer, true)
      end)

      -- code lens
      if vim.lsp.codelens then
        ---@diagnostic disable-next-line: unused-local
        util_lsp.on_supports_method("textDocument/codeLens", function(client, buffer)
          vim.lsp.codelens.refresh()
          vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            buffer = buffer,
            callback = vim.lsp.codelens.refresh,
          })
        end)
      end
    end
  end,
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
}
