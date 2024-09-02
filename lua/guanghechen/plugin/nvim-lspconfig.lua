local util_lsp = require("guanghechen.util.lsp")

return {
  name = "nvim-lspconfig",
  event = { "BufReadPre", "BufWritePost", "VeryLazy" },
  config = function()
    local severity = vim.diagnostic.severity
    vim.diagnostic.config({
      virtual_text = {
        prefix = "",
      },
      signs = {
        text = {
          [severity.ERROR] = eve.icons.diagnostics.Error,
          [severity.WARN] = eve.icons.diagnostics.Warning,
          [severity.INFO] = eve.icons.diagnostics.Information,
          [severity.HINT] = eve.icons.diagnostics.Hint,
        },
        numhl = {
          [severity.ERROR] = "f_lnum_error",
          [severity.WARN] = "f_lnum_warn",
          [severity.INFO] = "f_lnum_info",
          [severity.HINT] = "f_lnum_hint",
        },
      },
      underline = true,
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
