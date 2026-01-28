-- https://github.com/neovim/nvim-lspconfig/blob/aaa807fb2ea8d3caf41c153a174c6b7e472a8428/lsp/vue_ls.lua
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

  local retries = 0

  ---@param _                           lsp.ResponseError|nil
  ---@param result                      any
  ---@param context                     lsp.HandlerContext
  local function typescriptHandler(_, result, context)
    local ts_client = vim.lsp.get_clients({ bufnr = context.bufnr, name = "vtsls" })[1]

    if not ts_client then
      -- there can sometimes be a short delay until `vtsls` is attached so we retry for a few times until it is ready
      if retries <= 10 then
        retries = retries + 1
        vim.defer_fn(function()
          typescriptHandler(_, result, context)
        end, 100)
      else
        stl.reporter.error({
          from = "lsp.vue_ls",
          subject = "typescriptHandler",
          message = "Could not find `vtsls` lsp client required by `vue_ls`.",
        })
      end
      return
    end

    local param = unpack(result)
    local id, command, payload = unpack(param)
    ts_client:exec_cmd({
      title = "vue_request_forward",
      command = "typescript.tsserverRequest",
      arguments = {
        command,
        payload,
      },
    }, { bufnr = context.bufnr }, function(_, r)
      local response_data = { { id, r and r.body } }
      ---@diagnostic disable-next-line: param-type-mismatch
      client:notify("tsserver/response", response_data)
    end)
  end

  client.handlers["tsserver/request"] = typescriptHandler
end

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "vue-language-server", "--stdio" },
  filetypes = { "vue" },
  root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
  init_options = {
    typescript = {
      tsdk = yoz.path.locate_nearest(dot.path.cwd(), { dot.path.normalize("node_modules/typescript/lib") }),
    },
  },
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
