local opts = {
  log_level = vim.log.levels.ERROR,
  notify_on_error = true,
  formatters_by_ft = {
    -- web --
    javascript = { "prettier" },
    typescript = { "prettier" },
    javascriptreact = { "prettier" },
    typescriptreact = { "prettier" },
    svelte = { "prettier" },
    css = { "prettier" },
    html = { "prettier" },
    json = { "prettier" },
    yaml = { "prettier" },
    markdown = { "prettier" },
    graphql = { "prettier" },

    -- shell --
    bash = { "shfmt" },

    -- lua --
    lua = { "stylua" },

    -- python --
    python = { "isort", "black" },

    ["*"] = { "codespell" },
    ["_"] = { "trim_whitespace" },
  },
  format_on_save = {
    lsp_fallback = true,
    async = false,
    quiet = false,
    timeout_ms = 500,
  },
  format_after_save = {
    lsp_fallback = true,
  },
}

return opts
