-- https://github.com/neovim/nvim-lspconfig/blob/2bf52f747b8633d38b671d0e9b968ec0a3133bcb/lsp/svelte.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#svelte

---@type string[]
local CONFIG_FILENAMES = {
  "svelte.config.js",
  "svelte.config.mjs",
  "svelte.config.cjs",
  "package.json",
  "tsconfig.json",
  "jsconfig.json",
  ".git",
}

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  -- Svelte LSP only supports file:// schema. https://github.com/sveltejs/language-tools/issues/2777
  if vim.uv.fs_stat(filepath) == nil then
    return
  end
  local rootdir = era.m.lsp.fn.locate_lsp_root(filepath, CONFIG_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  era.m.lsp.event.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@return nil
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)

  -- Workaround to trigger reloading JS/TS files
  -- See https://github.com/sveltejs/language-tools/issues/2008
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = { "*.js", "*.ts" },
    group = vim.api.nvim_create_augroup("lspconfig.svelte", {}),
    callback = function(ctx)
      -- internal API to sync changes that have not yet been saved to the file system
      ---@diagnostic disable-next-line: param-type-mismatch
      client:notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
    end,
  })

  vim.api.nvim_buf_create_user_command(bufnr, "LspMigrateToSvelte5", function()
    client:exec_cmd({
      title = "Migrate Component to Svelte 5 Syntax",
      command = "migrate_to_svelte_5",
      arguments = { vim.uri_from_bufnr(bufnr) },
    })
  end, { desc = "Migrate Component to Svelte 5 Syntax" })
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

local svelteserver = era.m.lsp.fn.locate_mason_bin_path("svelteserver", true) or "svelteserver"

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { svelteserver, "--stdio" },
  filetypes = { "svelte" },
  root_markers = { "svelte.config.js", "svelte.config.mjs", "svelte.config.cjs", "package.json", ".git" },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
