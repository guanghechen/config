-- Upstream reference: https://github.com/neovim/nvim-lspconfig/blob/ac062d0d01c019c0dbdb798968f3e5d8b35c3853/lsp/tailwindcss.lua
-- Derived from nvim-lspconfig (Apache-2.0); license in lua/era/m/lsp/init.lua.
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#tailwindcss

---@type string[]
local CONFIG_FILENAMES = {
  -- Generic
  "tailwind.config.js",
  "tailwind.config.cjs",
  "tailwind.config.mjs",
  "tailwind.config.ts",
  "postcss.config.js",
  "postcss.config.cjs",
  "postcss.config.mjs",
  "postcss.config.ts",
  -- Django
  "theme/static_src/tailwind.config.js",
  "theme/static_src/tailwind.config.cjs",
  "theme/static_src/tailwind.config.mjs",
  "theme/static_src/tailwind.config.ts",
  "theme/static_src/postcss.config.js",
  -- Fallback for tailwind v4, where tailwind.config.* is not required anymore
  ".git",
}

---@type string[]
local filetypes = {
  "css",
  "less",
  "postcss",
  "sass",
  "scss",
  "stylus",
  "handlebars",
  "hbs",
  "html",
  "javascript",
  "javascriptreact",
  "mdx",
  "svelte",
  "templ",
  "typescript",
  "typescriptreact",
}

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir = era.m.lsp.fn.locate_lsp_root(filename, CONFIG_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

---@param _                             lsp.InitializeParams
---@param config                        table
---@return nil
local function before_init(_, config)
  config.settings = config.settings or {}
  config.settings.editor = config.settings.editor or {}
  config.settings.editor.tabSize = config.settings.editor.tabSize or vim.lsp.util.get_effective_tabstop()
end

local capabilities = era.m.lsp.event.get_capabilities()
local workspace = capabilities.workspace --[[@as lsp.WorkspaceClientCapabilities]]
local watched_files = workspace.didChangeWatchedFiles --[[@as lsp.DidChangeWatchedFilesClientCapabilities]]
watched_files.dynamicRegistration = true

---@type vim.lsp.Config
return {
  capabilities = capabilities,
  cmd = function(dispatchers, config)
    local command = config.root_dir and era.m.lsp.fn.locate_node_bin(config.root_dir, "tailwindcss-language-server")
      or "tailwindcss-language-server"
    return vim.lsp.rpc.start({ command, "--stdio" }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = filetypes,
  workspace_required = true,
  settings = {
    tailwindCSS = {
      validate = true,
      lint = {
        cssConflict = "warning",
        invalidApply = "error",
        invalidScreen = "error",
        invalidVariant = "error",
        invalidConfigPath = "error",
        invalidTailwindDirective = "error",
        recommendedVariantOrder = "warning",
      },
      classAttributes = {
        "class",
        "className",
        "class:list",
        "classList",
        "ngClass",
      },
      includeLanguages = {
        eelixir = "html-eex",
        elixir = "phoenix-heex",
        eruby = "erb",
        heex = "phoenix-heex",
        htmlangular = "html",
        templ = "html",
      },
    },
  },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = era.m.lsp.event.on_attach,
  on_detach = era.m.lsp.event.on_detach,
}
