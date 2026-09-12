---@see https://github.com/stevearc/conform.nvim

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.plugin.conform" ---@type string

-- stylua: ignore start
local formatters_by_ft = {
  -- web --
  css               = { "biome", "prettier", stop_after_first = true },
  graphql           = { "biome", "prettier", stop_after_first = true },
  handlebars        = { "prettier" },
  html              = { "prettier" },
  json              = { "biome", "prettier", stop_after_first = true },
  jsonc             = { "biome", "prettier", stop_after_first = true },
  javascript        = { "biome", "prettier", stop_after_first = true },
  javascriptreact   = { "biome", "prettier", stop_after_first = true },
  less              = { "prettier" },
  markdown          = { "prettier", "injected" },
  ["markdown.mdx"]  = { "prettier", "injected" },
  svelte            = { "prettier" },
  typescript        = { "biome", "prettier", stop_after_first = true },
  typescriptreact   = { "biome", "prettier", stop_after_first = true },
  yaml              = { "prettier" },

  -- shell --
  bash              = { "shfmt" },
  fish              = { "fish_indent" },
  sh                = { "shfmt" },
  zsh               = { "shfmt" },

  -- lang --
  dart              = { "dart_format" },
  lua               = { "stylua" },
  python            = { "isort", "black" },
  rust              = { "rustfmt", lsp_format = "never" },

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

---@class era.plugin.conform.config
local config = {
  prettier_bin_path = stl.env.IS_WIN and dot.path.normalize("node_modules/.bin/prettier.cmd")
    or dot.path.normalize("node_modules/.bin/prettier"),
  stylua_fallback_config_path = dot.path.locate_config_shared_filepath("stylua.toml"),
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
  ---@return string|nil
  find_stylua_config = function(dirname)
    local config_files = { ".stylua.toml", "stylua.toml" }
    return yoz.path.locate_nearest(dirname, config_files)
  end,

  ---@param dirname                     string
  ---@return string
  find_prettier_binpath = function(dirname)
    local binpath = yoz.path.locate_nearest(dirname, { config.prettier_bin_path }) ---@type string|nil
    return binpath or era.m.lsp.fn.locate_mason_bin_path("prettier") ---@type string
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
    return yoz.path.locate_nearest(dirname, config_files)
  end,

  ---@param config_table                table
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
      quiet = false,
      lsp_format = "fallback",
    },
    formatters_by_ft = formatters_by_ft,
    formatters = {
      biome = {
        require_cwd = true,
        command = function(_, ctx)
          return era.m.lsp.fn.locate_node_bin(ctx.dirname, "biome") or "biome"
        end,
        cwd = function(_, ctx)
          return vim.fs.root(ctx.dirname, { { "biome.json", "biome.jsonc" } })
        end,
        condition = function(self, ctx)
          local cwd = self:cwd(ctx)
          if cwd == nil then
            return false
          end

          -- Let Biome resolve JSONC, extends and per-file overrides without parsing buffer contents.
          local result = vim
            .system({ self:command(ctx), "format", "--stdin-file-path", ctx.filename, "--colors=off" }, {
              cwd = cwd,
              stdin = "",
              text = true,
              timeout = 1000,
            })
            :wait()
          -- Keep configuration and execution errors visible instead of silently switching formatters.
          return not (
            result.code == 1
            and (result.stderr or ""):find(
              "The content was not formatted because the formatter is currently disabled.",
              1,
              true
            )
          )
        end,
      },
      injected = {
        options = {
          ignore_errors = true,
        },
      },
      stylua = {
        prepend_args = function(_, ctx)
          local stylua_config_path = fns.find_stylua_config(ctx.dirname)
          if stylua_config_path then
            return { "--config-path", stylua_config_path }
          else
            return { "--config-path", config.stylua_fallback_config_path }
          end
        end,
      },
      prettier = {
        prepend_args = function(_, ctx)
          local args = { "--ignore-path=" } ---@type string[]

          -- Check for existing prettier config
          local prettier_config_path = fns.find_prettier_config(ctx.dirname)
          if prettier_config_path then
            -- Use existing config file
            table.insert(args, "--config=" .. prettier_config_path)
          else
            -- Use fallback config
            local fallback_config = vim.deepcopy(config.prettier_fallback_config)

            -- Override prose-wrap for non-markdown files
            if vim.api.nvim_get_option_value("filetype", { buf = ctx.buf }) ~= "markdown" then
              fallback_config.proseWrap = "preserve"
            end
            vim.list_extend(args, fns.config_to_args(fallback_config))
          end

          return args
        end,
        command = function(_, ctx)
          return fns.find_prettier_binpath(ctx.dirname)
        end,
      },
      rustfmt = {
        options = {
          -- The default edition of Rust to use when no Cargo.toml file is found
          default_edition = "2021",
        },
      },
    },
    format_on_save = function(bufnr)
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
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
