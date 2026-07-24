-- https://github.com/neovim/nvim-lspconfig/blob/78596b61676d361a74ea3f3abbbf83d5fe6f5519/lsp/denols.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#denols

---@param uri                           string
---@param res                           {result: string}|nil
---@param client                        vim.lsp.Client
---@return nil
local function virtual_text_document_handler(uri, res, client)
  if not res then
    return nil
  end

  local lines = vim.split(res.result, "\n")
  local bufnr = vim.uri_to_bufnr(uri)

  local current_buf = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #current_buf ~= 0 then
    return nil
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.lsp.buf_attach_client(bufnr, client.id)
end

---@param uri                           string
---@param client                        vim.lsp.Client
---@return nil
local function virtual_text_document(uri, client)
  local params = {
    textDocument = {
      uri = uri,
    },
  }
  local result = client:request_sync("deno/virtualTextDocument", params) ---@diagnostic disable-line: param-type-mismatch
  virtual_text_document_handler(uri, result, client)
end

---@param err                           lsp.ResponseError|nil
---@param result                        table|nil
---@param ctx                           lsp.HandlerContext
---@param config                        table|nil
---@return nil
local function denols_handler(err, result, ctx, config)
  if not result or vim.tbl_isempty(result) then
    return nil
  end

  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    return nil
  end

  for _, res in pairs(result) do
    local uri = res.uri or res.targetUri
    if uri:match("^deno:") then
      virtual_text_document(uri, client)
      res["uri"] = uri
      res["targetUri"] = uri
    end
  end

  vim.lsp.handlers[ctx.method](err, result, ctx, config)
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir, project_type = era.m.lsp.fn.locate_js_project_root(filepath) ---@type string|nil, "deno"|"node"
  if project_type == "deno" then
    on_dir(rootdir)
  end
end

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  era.m.lsp.event.before_init(params, config)
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
  handlers = {
    ["textDocument/definition"] = denols_handler,
    ["textDocument/typeDefinition"] = denols_handler,
    ["textDocument/references"] = denols_handler,
  },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
