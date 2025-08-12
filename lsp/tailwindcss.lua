-- https://github.com/neovim/nvim-lspconfig/blob/1ddc1a2e692b120cda6d33c890461e49cb85d6bf/lsp/tailwindcss.lua
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
  "javascript.jsx",
  "javascriptreact",
  "markdown",
  "mdx",
  "svelte",
  "typescript",
  "typescript.tsx",
  "typescriptreact",
  "vue",
}

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir = eve.lsp.locate_lsp_root(filename, CONFIG_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

---@return string|nil
local function detectLspServer()
  local _, binPath = eve.lsp.locate_lsp_root(
    std.path.cwd() .. std.env.PATH_SEP .. "a.css",
    { "./node_modules/.bin/tailwindcss-language-server" }
  )
  if binPath ~= nil and vim.fn.executable(binPath) == 1 then
    return binPath
  end
  return nil
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)

  config.settings = config.settings or {}
  config.settings.editor = config.settings.editor or {}
  config.settings.editor.tabSize = config.settings.editor.tabSize or vim.lsp.util.get_effective_tabstop()
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  eve.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

local lspBinPath = detectLspServer()

return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = lspBinPath and { lspBinPath, "--stdio" } or nil,
  filetypes = filetypes,
  filetypes_exclude = { "markdown" },
  filetypes_include = { "css", "javascriptreact", "javascript.jsx", "typescriptreact", "typescript.tsx" },
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
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
