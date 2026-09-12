---@diagnostic disable-next-line: unused-local
local __module_name__ = "lsp.biome" ---@type string

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = function(dispatchers, config)
    local command = era.m.lsp.fn.locate_node_bin(config.root_dir, "biome") or "biome"
    return vim.lsp.rpc.start({ command, "lsp-proxy" }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = {
    "astro",
    "css",
    "graphql",
    "html",
    "javascript",
    "javascriptreact",
    "json",
    "jsonc",
    "svelte",
    "typescript",
    "typescriptreact",
    "vue",
  },
  root_dir = function(bufnr, on_dir)
    local rootdir = vim.fs.root(bufnr, { { "biome.json", "biome.jsonc" } }) ---@type string|nil
    if rootdir == nil then
      return
    end

    local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)) ---@type string
    local _, bin_root = era.m.lsp.fn.locate_node_bin(dirname, "biome") ---@type string|nil, string|nil
    -- A package-local binary needs its own client while inheriting the ancestor configuration.
    if bin_root ~= nil and #bin_root > #rootdir then
      rootdir = bin_root
    end
    on_dir(rootdir)
  end,
  workspace_required = true,
  before_init = era.m.lsp.event.before_init,
  on_attach = era.m.lsp.event.on_attach,
  on_detach = era.m.lsp.event.on_detach,
  on_init = era.m.lsp.event.on_init,
}
