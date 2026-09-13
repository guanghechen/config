---@diagnostic disable-next-line: unused-local
local __module_name__ = "lsp.tsc" ---@type string

local TypeScript = require("era.m.lsp.typescript")

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@return nil
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)

  ---@type stl.t.IKeymap[]
  local keymaps = {}
  for _, action in ipairs({
    { key = "<leader>co", kind = "source.organizeImports", desc = "lsp: organize imports" },
    { key = "<leader>c-", kind = "source.removeUnusedImports", desc = "lsp: remove unused imports" },
    { key = "<leader>cf", kind = "source.fixAll", desc = "lsp: fix all" },
  }) do
    keymaps[#keymaps + 1] = {
      modes = { "n", "v" },
      key = action.key,
      desc = action.desc,
      callback = function()
        vim.lsp.buf.code_action({
          apply = true,
          context = { only = { action.kind }, diagnostics = {} },
          filter = function(_, client_id)
            return client_id == client.id
          end,
        })
      end,
    }
  end
  era.m.lsp.event.bindkeys(client, bufnr, keymaps)
  TypeScript.on_attach(client, bufnr)
end

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = function(dispatchers, config)
    local binpath =
      assert(TypeScript.get_tsc_binpath(config.root_dir), "Project TypeScript 7 executable is no longer available")
    return vim.lsp.rpc.start({ binpath, "--lsp", "--stdio" }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  workspace_required = true,
  root_dir = function(bufnr, on_dir)
    local project = TypeScript.select_for_buffer(bufnr, "tsc")
    if project.server == "tsc" then
      on_dir(project.root_dir)
    end
  end,
  settings = {
    ["js/ts"] = {
      updateImportsOnFileMove = { enabled = "always" },
      inlayHints = {
        enumMemberValues = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        variableTypes = { enabled = false },
      },
    },
  },
  before_init = era.m.lsp.event.before_init,
  on_attach = on_attach,
  on_detach = era.m.lsp.event.on_detach,
  on_init = era.m.lsp.event.on_init,
}
