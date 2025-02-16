local lsp = require("eve.builtin.lsp")
local icons = require("eve.constant.icon")
local state = require("eve.state")

local severity = vim.diagnostic.severity

---@type table<vim.diagnostic.Severity, string>
local severity2prefixicon = {
  [severity.ERROR] = icons.diagnostic.Error_alt,
  [severity.WARN] = icons.diagnostic.Warning_alt,
  [severity.INFO] = icons.diagnostic.Information_alt,
  [severity.HINT] = icons.diagnostic.Hint_alt,
}

---@type table<vim.diagnostic.Severity, string>
local severity2texticon = {
  [severity.ERROR] = icons.diagnostic.Error,
  [severity.WARN] = icons.diagnostic.Warning,
  [severity.INFO] = icons.diagnostic.Information,
  [severity.HINT] = icons.diagnostic.Hint,
}

---@type table<vim.diagnostic.Severity, string>
local severity2numhl = {
  [severity.ERROR] = "f_lnum_error",
  [severity.WARN] = "f_lnum_warn",
  [severity.INFO] = "f_lnum_info",
  [severity.HINT] = "f_lnum_hint",
}

return {
  name = "nvim-lspconfig",
  event = { "BufReadPost", "BufNewFile", "BufWritePre" },
  config = function()
    vim.diagnostic.config({
      virtual_text = {
        source = "if_many",
        spacing = 4,
        prefix = function(diagnostic)
          return severity2prefixicon[diagnostic.severity] or ""
        end,
      },
      signs = {
        text = severity2texticon,
        numhl = severity2numhl,
      },
      severity_sort = true,
      underline = true,
      update_in_insert = false,
      float = {
        focus = true,
        focusable = true,
        border = "rounded",
      },
    })

    local original_register_capability = vim.lsp.handlers["client/registerCapability"]
    vim.lsp.handlers["client/registerCapability"] = function(err, res, ctx)
      local ret = original_register_capability(err, res, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client then
        for bufnr in pairs(client.attached_buffers) do
          lsp.check_methods(client, bufnr)
        end
      end
      return ret
    end

    -- inlay hints
    ---@diagnostic disable-next-line: unused-local
    lsp.on_supports_method("textDocument/inlayHint", function(client, bufnr)
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
        local enable_lsp_inlay_hints = state.flight.lsp_inlay_hints:snapshot() ---@type boolean
        vim.lsp.inlay_hint.enable(enable_lsp_inlay_hints, { bufnr = bufnr })
      end
    end)

    -- code lens
    if vim.lsp.codelens then
      ---@diagnostic disable-next-line: unused-local
      lsp.on_supports_method("textDocument/codeLens", function(client, bufnr)
        local enable_lsp_code_lens = state.flight.lsp_code_lens:snapshot() ---@type boolean
        if enable_lsp_code_lens and vim.bo[bufnr].buftype == "" then
          vim.lsp.codelens.refresh()
          --- vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
          vim.api.nvim_create_autocmd({ "InsertLeave" }, {
            buffer = bufnr,
            callback = vim.lsp.codelens.refresh,
          })
        end
      end)
    end
  end,
  dependencies = {
    "mason.nvim",
    "mason-lspconfig.nvim",
  },
}
