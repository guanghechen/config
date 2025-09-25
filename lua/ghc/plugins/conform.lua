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
  prettier_fallback_config = {
    arrowParens = "avoid",
    bracketSameLine = false,
    bracketSpacing = true,
    embeddedLanguageFormatting = "off",
    endOfLine = "lf",
    htmlWhitespaceSensitivity = "strict",
    jsxSingleQuote = false,
    printWidth = 100,
    proseWrap = "always",
    quoteProps = "as-needed",
    semi = false,
    singleQuote = true,
    trailingComma = "all",
    useTabs = false,
  },
}

local fns = {
  ---@param dirname                     string
  ---@return string
  find_prettier_binpath = function(dirname)
    local binpath = std.path.locate_nearest_filepath(dirname, { config.prettier_bin_path }) ---@type string|nil
    return binpath or eve.lsp.locate_mason_bin_path("prettier") ---@type string
  end,

  ---@param dirname                     string
  ---@return string|nil
  find_prettier_config = function(dirname)
    local config_files = {
      ".prettierrc",
      ".prettierrc.json",
      ".prettierrc.yml",
      ".prettierrc.yaml",
      ".prettierrc.js",
      ".prettierrc.mjs",
      ".prettierrc.cjs",
      "prettier.config.js",
      "prettier.config.mjs",
      "prettier.config.cjs",
    }
    return std.path.locate_nearest_filepath(dirname, config_files)
  end,

  ---@param config_table table
  ---@return string[]
  config_to_args = function(config_table)
    local args = {}
    for key, value in pairs(config_table) do
      local kebab_key = key:gsub("([a-z])([A-Z])", "%1-%2"):lower()
      if type(value) == "boolean" then
        if value then
          table.insert(args, "--" .. kebab_key)
        else
          table.insert(args, "--no-" .. kebab_key)
        end
      else
        table.insert(args, "--" .. kebab_key .. "=" .. tostring(value))
      end
    end
    return args
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
        prepend_args = function(_, ctx)
          local args = {
            "--ignore-path=",
            "--stdin-filepath",
            vim.api.nvim_buf_get_name(ctx.buf),
          }

          -- Check for existing prettier config
          local prettier_config_path = fns.find_prettier_config(ctx.dirname)
          if prettier_config_path then
            -- Use existing config file
            table.insert(args, "--config=" .. prettier_config_path)
          else
            -- Use fallback config
            local fallback_config = vim.deepcopy(config.prettier_fallback_config)

            -- Override prose-wrap for non-markdown files
            if vim.bo[ctx.buf].filetype ~= "markdown" then
              fallback_config.proseWrap = "preserve"
            end

            local config_args = fns.config_to_args(fallback_config)
            vim.list_extend(args, config_args)
          end

          return args
        end,
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
