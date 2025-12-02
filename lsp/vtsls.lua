-- https://github.com/neovim/nvim-lspconfig/blob/78174f395e705de97d1329c18394831737d9a4b4/lsp/vtsls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#vtsls

local __module_name__ = "lsp.vtsls" ---@type string

local Methods = vim.lsp.protocol.Methods

---@type string[]
local CONFIG_FILENAMES = {
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
  client.commands["_typescript.moveToFileRefactoring"] = function(lsp_command)
    local action, uri, range = unpack(lsp_command.arguments)
    ---@cast action                     string
    ---@cast uri                        string
    ---@cast range                      lsp.Range

    local function move(new_filename)
      client:request(Methods.workspace_executeCommand, {
        command = lsp_command.command,
        arguments = { action, uri, range, new_filename },
      })
    end

    local fname = vim.uri_to_fname(uri)
    client:request(Methods.workspace_executeCommand, {
      command = "typescript.tsserverRequest",
      arguments = {
        "getMoveToRefactoringFileSuggestions",
        {
          file = fname,
          startLine = range.start.line + 1,
          startOffset = range.start.character + 1,
          endLine = range["end"].line + 1,
          endOffset = range["end"].character + 1,
        },
      },
    }, function(_, result)
      ---@type string[]
      local files = result.body.files
      table.insert(files, 1, "Enter new path...")
      vim.ui.select(files, {
        name = __module_name__,
        prompt = "Select move destination:",
        format_item = function(f)
          return vim.fn.fnamemodify(f, ":~:.")
        end,
      }, function(f)
        if f and f:find("^Enter new path") then
          vim.ui.input({
            prompt = "Enter move destination:",
            default = vim.fn.fnamemodify(fname, ":h") .. "/",
            completion = "file",
          }, function(new_filename)
            return new_filename and move(new_filename)
          end)
        elseif f then
          move(f)
        end
      end)
    end)
  end

  eve.lsp.on_attach(client, bufnr)

  ---@type std.t.IKeymap[]
  local keymaps = {
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
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr })
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

local paths = {
  vue_ls = eve.lsp.locate_mason_pkg_path("vue-language-server", "/node_modules/@vue/language-server", true),
}

local vue_plugin = paths.vue_ls and {
  name = "@vue/typescript-plugin",
  location = paths.vue_ls,
  languages = { "vue" },
  configNamespace = "typescript",
  enableForWorkspaceTypeScriptVersions = true,
} or nil

local global_plugins = {} ---@type table[]
if vue_plugin then
  global_plugins[#global_plugins + 1] = vue_plugin
end

---@type vim.lsp.Config
return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = { "vtsls", "--stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  init_options = {
    hostInfo = "neovim",
  },
  root_markers = { "tsconfig.json", "package.json", "jsconfig.json", ".git" },
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
          globalPlugins = global_plugins,
        },
      },
      typescript = {
        tsdk = rstd.path.locate_nearest(std.path.cwd(), { std.path.normalize("node_modules/typescript/lib") }),
        globalTsdk = rstd.path.locate_nearest(std.path.cwd(), { std.path.normalize("node_modules/typescript/lib") }),
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
      javascript = {
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
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
