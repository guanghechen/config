-- https://github.com/neovim/nvim-lspconfig/blob/78596b61676d361a74ea3f3abbbf83d5fe6f5519/lsp/denols.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#denols

-- Deno 2 serves remote modules and its own declarations as file URIs under its cache, so no deno:
-- virtual documents need fetching.

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir, project_type = era.m.lsp.fn.locate_js_project_root(filepath) ---@type string|nil, "deno"|"node"
  if project_type == "deno" then
    on_dir(rootdir)
  end
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)

  vim.api.nvim_buf_create_user_command(bufnr, "LspDenolsCache", function()
    client:exec_cmd({
      title = "DenolsCache",
      command = "deno.cache",
      arguments = { {}, vim.uri_from_bufnr(bufnr) },
    }, { bufnr = bufnr }, function(err, _, ctx)
      if err then
        local uri = ctx.params.arguments[2]
        vim.notify("cache command failed for " .. vim.uri_to_fname(uri), vim.log.levels.ERROR)
      end
    end)
  end, {
    desc = "Cache a module and all of its dependencies.",
  })
end

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "deno", "lsp" },
  cmd_env = { NO_COLOR = true },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  root_markers = { "deno.lock", "deno.json", "deno.jsonc", ".git" },
  settings = {
    deno = {
      enable = true,
      suggest = {
        imports = {
          hosts = {
            ["https://deno.land"] = true,
          },
        },
      },
    },
  },
  root_dir = root_dir,
  on_attach = on_attach,
}
