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
  rust              = { "rustfmt" },

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

---@class ghc.plugin.conform.config
local config = {
  prettier_bin_path = std.env.IS_WIN and std.path.normalize("node_modules/.bin/prettier.cmd")
    or std.path.normalize("node_modules/.bin/prettier"),
}

local fns = {
  ---@param dirname                     string
  ---@return string
  find_prettier_binpath = function(dirname)
    local binpath = std.path.locate_nearest_filepath(dirname, { config.prettier_bin_path }) ---@type string|nil
    return binpath or eve.lsp.locate_mason_bin_path("prettier") ---@type string
  end,
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
        command = function(_, ctx)
          return fns.find_prettier_binpath(ctx.dirname)
        end,
      },
      rustfmt = {
        -- The default edition of Rust to use when no Cargo.toml file is found
        default_edition = "2021",
      },
    },
    format_on_save = function(bufnr)
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
  config = function(_, opts)
    require("conform").setup(opts)

    -- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
