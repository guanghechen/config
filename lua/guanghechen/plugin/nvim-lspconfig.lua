local util_lsp = require("guanghechen.util.lsp")

local function register_lsp_symbol(name, icon)
  local hl = "DiagnosticSign" .. name
  vim.fn.sign_define(hl, { text = icon, numhl = hl, texthl = hl })
end

return {
  name = "nvim-lspconfig",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  config = function()
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

    -- inlay hints
    ---@diagnostic disable-next-line: unused-local
    util_lsp.on_supports_method("textDocument/inlayHint", function(client, bufnr)
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
      end
    end)

    -- code lens
    if vim.lsp.codelens then
      ---@diagnostic disable-next-line: unused-local
      util_lsp.on_supports_method("textDocument/codeLens", function(client, bufnr)
        vim.lsp.codelens.refresh()
        vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
          buffer = bufnr,
          callback = vim.lsp.codelens.refresh,
        })
      end)
    end
  end,
  dependencies = {
    "mason.nvim",
    "mason-lspconfig.nvim",
  },
}
