local functional = require("eve.lib.functional")
local bindkeys = require("eve.lib.nvim").bindkeys
local path = require("eve.lib.path")
local capabilities = require("guanghechen.lsp.common").capabilities
local handlers = require("guanghechen.lsp.common").handlers
local basic_on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  basic_on_attach(client, bufnr)

  ---@type eve.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "gD",
      callback = function()
        local params = vim.lsp.util.make_position_params()
        require("trouble").open({
          mode = "lsp_command",
          params = {
            command = "typescript.goToSourceDefinition",
            arguments = { params.textDocument.uri, params.position },
          },
        })
      end,
      desc = "lsp: goto source definition",
    },
    {
      modes = { "n" },
      key = "gR",
      callback = function()
        require("trouble").open({
          mode = "lsp_command",
          params = {
            command = "typescript.findAllFileReferences",
            arguments = { vim.uri_from_bufnr(0) },
          },
        })
      end,
      desc = "lsp: find all references",
    },
    {
      modes = { "n", "v" },
      key = "<leader>co",
      callback = function()
        vim.lsp.buf.code_action({
          apply = true,
          context = {
            only = { "source.organizeImports" },
            diagnostics = {},
          },
        })
      end,
      desc = "lsp: organize imports",
    },
    {
      modes = { "n", "v" },
      key = "<leader>c+",
      callback = function()
        vim.lsp.buf.code_action({
          apply = true,
          context = {
            ---@diagnostic disable-next-line: assign-type-mismatch
            only = { "source.addMissingImports.ts" },
            diagnostics = {},
          },
        })
      end,
      desc = "lsp: add missing imports",
    },
    {
      modes = { "n", "v" },
      key = "<leader>c-",
      callback = function()
        vim.lsp.buf.code_action({
          apply = true,
          context = {
            ---@diagnostic disable-next-line: assign-type-mismatch
            only = { "source.removeUnused.ts" },
            diagnostics = {},
          },
        })
      end,
      desc = "lsp: remove unused imports",
    },
    {
      modes = { "n", "v" },
      key = "<leader>cf",
      callback = function()
        vim.lsp.buf.code_action({
          apply = true,
          context = {
            ---@diagnostic disable-next-line: assign-type-mismatch
            only = { "source.fixAll.ts" },
            diagnostics = {},
          },
        })
      end,
      desc = "lsp: fix all",
    },
  }
  bindkeys(keymaps, { bufnr = bufnr })
end

local plugins = {
  vue = path.locate_mason_pkg_path("vue-language-server", "/node_modules/@vue/language-server", true),
}

return {
  capabilities = capabilities,
  handlers = handlers,
  on_attach = on_attach,
  on_init = on_init,
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  root_dir = function(filename)
    local util = require("lspconfig.util")
    return util.root_pattern(".git")(filename)
      or util.root_pattern("package.json", "tsconfig.json", "jsconfig.json")(filename)
  end,
  settings = {
    complete_function_calls = true,
    vtsls = {
      complete_function_calls = true,
      vtsls = {
        enableMoveToFileCodeAction = true,
        autoUseWorkspaceTsdk = true,
        experimental = {
          maxInlayHintLength = 30,
          completion = {
            enableServerSideFuzzyMatch = true,
          },
        },
        tsserver = {
          globalPlugins = vim.tbl_filter(functional.booleanify, {
            plugins.vue and {
              name = "@vue/typescript-plugin",
              location = plugins.vue,
              languages = { "vue" },
              configNamespace = "typescript",
              enableForWorkspaceTypeScriptVersions = true,
            },
          }),
        },
      },
      typescript = {
        updateImportsOnFileMove = { enabled = "always" },
        suggest = {
          completeFunctionCalls = true,
        },
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
  },
}
