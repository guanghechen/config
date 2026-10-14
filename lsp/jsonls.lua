-- Upstream reference: https://github.com/neovim/nvim-lspconfig/blob/ac062d0d01c019c0dbdb798968f3e5d8b35c3853/lsp/jsonls.lua
-- Derived from nvim-lspconfig (Apache-2.0); license in lua/era/m/lsp/init.lua.
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#jsonls

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
  cmd = function(dispatchers, config)
    local command = config.root_dir and era.m.lsp.fn.locate_node_bin(config.root_dir, "vscode-json-language-server")
      or "vscode-json-language-server"
    return vim.lsp.rpc.start({ command, "--stdio" }, dispatchers, { cwd = config.root_dir })
  end,
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
  on_attach = era.m.lsp.event.on_attach,
  on_detach = era.m.lsp.event.on_detach,
}
