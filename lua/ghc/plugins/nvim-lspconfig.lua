local severity = vim.diagnostic.severity

---@type table<vim.diagnostic.Severity, string>
local severity2prefixicon = {
  [severity.ERROR] = eve.icon.diagnostic.Error_alt,
  [severity.WARN] = eve.icon.diagnostic.Warning_alt,
  [severity.INFO] = eve.icon.diagnostic.Information_alt,
  [severity.HINT] = eve.icon.diagnostic.Hint_alt,
}

---@type table<vim.diagnostic.Severity, string>
local severity2texticon = {
  [severity.ERROR] = eve.icon.diagnostic.Error,
  [severity.WARN] = eve.icon.diagnostic.Warning,
  [severity.INFO] = eve.icon.diagnostic.Information,
  [severity.HINT] = eve.icon.diagnostic.Hint,
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
        current_line = false,
        source = "if_many",
        spacing = 4,
        prefix = function(diagnostic)
          return severity2prefixicon[diagnostic.severity] or ""
        end,
      },
      virtual_lines = {
        current_line = true,
        format = function(diagnostic)
          local icon = severity2prefixicon[diagnostic.severity] or ""
          return string.format("%s %s", icon, diagnostic.message)
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
          eve.lsp.check_methods(client, bufnr)
        end
      end
      return ret
    end

    -- inlay hints
    eve.lsp.on_supports_method("textDocument/inlayHint", function(client, bufnr)
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
        local enable_inlay_hints = eve.state.lsp.inlay_hints:snapshot() ---@type boolean
        vim.lsp.inlay_hint.enable(enable_inlay_hints, { bufnr = bufnr })
      end
    end)

    -- code lens
    eve.lsp.on_supports_method("textDocument/codeLens", function(client, bufnr)
      if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
        local enable_code_lens = eve.state.lsp.code_lens:snapshot() ---@type boolean
        if enable_code_lens then
          vim.lsp.codelens.refresh()
          --- vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
          vim.api.nvim_create_autocmd({ "InsertLeave" }, {
            buffer = bufnr,
            callback = vim.lsp.codelens.refresh,
          })
        end
      end
    end)

    ---@type string[]
    local enabled = {
      "bashls",
      "clangd",
      "cssls",
      "docker_compose_language_service",
      "dockerls",
      "eslint",
      "html",
      "jsonls",
      "lua_ls",
      "pyright",
      "ruff",
      "rust_analyzer",
      "tailwindcss",
      "taplo",
      "vtsls",
      "yamlls",
    }
    for _, server in ipairs(enabled) do
      local module_name = "ghc.lsp." .. server
      local has_config, config_or_err = pcall(require, module_name)
      if has_config then
        require("lspconfig")[server].setup(config_or_err)
      else
        if string.match(config_or_err, "module '" .. module_name:gsub("%.", "%%.") .. "' not found") then
          require("lspconfig")[server].setup({})
        else
          error(config_or_err)
        end
      end
    end
  end,
  dependencies = {
    "mason.nvim",
  },
}
