-- https://github.com/neovim/nvim-lspconfig/blob/5a49a97f9d3de5c39a2b18d583035285b3640cb0/lsp/jsonls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#jsonls

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  era.m.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  era.m.lsp.event.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  era.m.lsp.event.on_init(client, config)
end

local schemas = {
  -- Web / JavaScript / TypeScript
  {
    fileMatch = { "package.json" },
    url = "https://www.schemastore.org/package.json",
  },
  {
    fileMatch = { "tsconfig*.json" },
    url = "https://www.schemastore.org/tsconfig.json",
  },
  {
    fileMatch = { "jsconfig.json" },
    url = "https://www.schemastore.org/jsconfig.json",
  },
  {
    fileMatch = { ".eslintrc", ".eslintrc.json", ".eslintrc.yml", ".eslintrc.yaml" },
    url = "https://www.schemastore.org/eslintrc.json",
  },
  {
    fileMatch = { "biome.json", "biome.jsonc" },
    url = "https://biomejs.dev/schemas/latest/schema.json",
  },
  {
    fileMatch = { "deno.json", "deno.jsonc" },
    url = "https://raw.githubusercontent.com/denoland/deno/main/cli/schemas/config-file.v1.json",
  },
  {
    fileMatch = { ".babelrc", ".babelrc.json", "babel.config.json" },
    url = "https://www.schemastore.org/babelrc.json",
  },
  {
    fileMatch = { ".prettierrc", ".prettierrc.json", ".prettierrc.yml", ".prettierrc.yaml" },
    url = "https://www.schemastore.org/prettierrc.json",
  },
  {
    fileMatch = { ".stylelintrc", ".stylelintrc.yml", ".stylelintrc.yaml", ".stylelintrc.json" },
    url = "https://www.schemastore.org/stylelintrc.json",
  },
  {
    fileMatch = { ".htmlvalidate.json" },
    url = "https://html-validate.org/schemas/config.json",
  },
  {
    fileMatch = {
      ".cspell.json",
      "cspell.json",
      ".cSpell.json",
      "cSpell.json",
      "cspell.config.json",
      "cspell.config.yaml",
      "cspell.config.yml",
      "cspell.yaml",
      "cspell.yml",
    },
    url = "https://raw.githubusercontent.com/streetsidesoftware/cspell/main/packages/cspell-types/cspell.schema.json",
  },
  {
    fileMatch = { "manifest.json", "*.webmanifest" },
    url = "https://www.schemastore.org/web-manifest-combined.json",
  },

  -- C / C++
  {
    fileMatch = { "CMakePresets.json", "CMakeUserPresets.json" },
    url = "https://raw.githubusercontent.com/Kitware/CMake/master/Help/manual/presets/schema.json",
  },
  {
    fileMatch = { "compile_commands.json" },
    url = "https://www.schemastore.org/compile-commands.json",
  },

  -- Rust
  {
    fileMatch = { "rust-project.json" },
    url = "https://www.schemastore.org/rust-project.json",
  },

  -- C#
  {
    fileMatch = { "appsettings.json", "appsettings.*.json" },
    url = "https://www.schemastore.org/appsettings.json",
  },
  {
    fileMatch = { "global.json" },
    url = "https://www.schemastore.org/global.json",
  },
  {
    fileMatch = { "launchsettings.json" },
    url = "https://www.schemastore.org/launchsettings.json",
  },
  {
    fileMatch = { "dotnet-tools.json" },
    url = "https://www.schemastore.org/dotnet-tools.json",
  },

  -- Go
  {
    fileMatch = { ".golangci.yml", ".golangci.yaml", ".golangci.toml", ".golangci.json" },
    url = "https://golangci-lint.run/jsonschema/golangci.jsonschema.json",
  },
}

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc", "excalidraw" },
  init_options = {
    provideFormatter = true,
  },
  root_markers = { ".git" },
  settings = {
    json = {
      format = {
        enable = true,
      },
      schemas = schemas,
      suggest = {
        json5 = true,
      },
      validate = {
        enable = true,
      },
    },
  },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
