-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#vue_ls

---@type string[]
local CONFIG_FILENAMES = {
  "package.json",
  "tsconfig.json",
  "jsconfig.json",
  ".git",
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
  "bun.lockb",
  "bun.lock",
}

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir = eve.lsp.locate_lsp_root(filepath, CONFIG_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@return nil
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

---@type vim.lsp.Config
return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = { "vue-language-server", "--stdio" },
  filetypes = { "vue" },
  root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
  init_options = {
    typescript = {
      tsdk = yoz.path.locate_nearest(std.path.cwd(), { std.path.normalize("node_modules/typescript/lib") }),
    },
  },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
