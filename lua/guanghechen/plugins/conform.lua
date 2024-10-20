return {
  name = "conform.nvim",
  cmd = "ConformInfo",
  event = { "VeryLazy" },
  opts = {
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
      jsonc = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },
      graphql = { "prettier" },

      -- shell --
      bash = { "shfmt" },
      sh = { "shfmt" },
      zsh = { "shfmt" },

      -- lua --
      lua = { "stylua" },

      -- python --
      python = { "isort", "black" },

      -- app --
      tmux = { "shfmt" },

      --      ["*"] = { "codespell" },
      ["_"] = { "trim_whitespace" },
    },
    format_on_save = function(bufnr)
      -- Disable autoformat on certain filetypes
      local ignore_filetypes = { "text", "tmux", "toml", "markdown", "sql" }
      if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
        return
      end

      -- Disable with a global or buffer-local variable
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end

      -- Disable autoformat for files in a certain path
      local ignore_filepaths = {
        ".git/",
        ".cache/",
        ".next/",
        ".yarn/",
        "build/",
        "debug/",
        "node_modules/",
        "target/",
        "yarn.lock",
        "npm-package.lock",
        "*.log",
        "*.pdf",
        "*.mkv",
        "*.mp4",
        "*.zip",
      }
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      for _, ignore_filepath in ipairs(ignore_filepaths) do
        if bufname:match(ignore_filepath) then
          return
        end
      end

      -- ...additional logic...
      return {
        async = false,
        lsp_fallback = true,
        quiet = false,
        timeout_ms = 500,
      }
    end,
  },
}
