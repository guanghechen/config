-- stylua: ignore start
local formatters_by_ft = {
  -- web --
  css               = { "prettier" },
  graphql           = { "prettier" },
  handlebars        = { "prettier" },
  html              = { "prettier" },
  json              = { "prettier" },
  jsonc             = { "prettier" },
  javascript        = { "prettier" },
  javascriptreact   = { "prettier" },
  less              = { "prettier" },
  markdown          = { "prettier" },
  ["markdown.mdx"]  = { "prettier" },
  svelte            = { "prettier" },
  typescript        = { "prettier" },
  typescriptreact   = { "prettier" },
  yaml              = { "prettier" },

  -- shell --
  bash              = { "shfmt" },
  fish              = { "fish_indent" },
  sh                = { "shfmt" },
  zsh               = { "shfmt" },

  -- lang --
  lua               = { "stylua" },
  python            = { "isort", "black" },
  rust              = { "rustfmt", lsp_format = "fallback" },

  -- app --
  tmux              = { "shfmt" },

  -- global --
  -- ["*"]             = { "cspell" },

  -- fallback --
  ["_"]             = { "trim_whitespace" },
}
-- stylua: ignore end

local ignored = {
  filetypes = {
    conf = true,
    text = true,
    tmux = true,
    toml = true,
    markdown = true,
    sql = true,
  },
  filepaths = {
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
  },
}

return {
  name = "conform.nvim",
  cmd = "ConformInfo",
  event = { "LspAttach", "BufReadPost", "BufNewFile" },
  opts = {
    log_level = vim.log.levels.ERROR,
    notify_on_error = true,
    notify_no_formatters = true,
    default_format_opts = {
      timeout_ms = 3000,
      async = false,
      quiet = false,
      lsp_format = "fallback",
    },
    formatters_by_ft = formatters_by_ft,
    formatters = {
      injected = {
        options = {
          ignore_errors = true,
        },
      },
      prettier = {
        prepend_args = { "--prose-wrap", "always" },
        condition = function(_, ctx)
          local bufnr = ctx.buf ---@type integer
          local filetype = vim.bo[bufnr].filetype
          local formatters = formatters_by_ft[filetype] or {} ---@type string[]
          if not vim.tbl_contains(formatters, "prettier") then
            return false
          end

          ---! Check if a parser can be inferred
          local ret = vim.fn.system({ "prettier", "--file-info", ctx.filename })
          local ok, parser = pcall(function()
            return vim.fn.json_decode(ret).inferredParser
          end)
          if not ok or not parser or parser == vim.NIL then
            return false
          end

          ---! Checks if a Prettier config file exists for the given context
          vim.fn.system({ "prettier", "--find-config-path", ctx.filename })
          return vim.v.shell_error == 0
        end,
      },
      rustfmt = {
        -- The default edition of Rust to use when no Cargo.toml file is found
        default_edition = "2021",
      },
    },
    format_on_save = function(bufnr)
      -- Disable with a global or buffer-local variable
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end

      local filetype = vim.bo[bufnr].filetype ---@type string
      if ignored.filetypes[filetype] then
        return
      end

      -- Disable autoformat for files in a certain path
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      for _, ignore_filepath in ipairs(ignored.filepaths) do
        if filepath:match(ignore_filepath) then
          return
        end
      end

      return {
        async = false,
        lsp_format = "fallback",
        quiet = false,
        timeout_ms = 3000,
      }
    end,
  },
}
