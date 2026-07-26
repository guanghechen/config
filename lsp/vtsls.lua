-- https://github.com/neovim/nvim-lspconfig/blob/78596b61676d361a74ea3f3abbbf83d5fe6f5519/lsp/vtsls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#vtsls

local __module_name__ = "lsp.vtsls" ---@type string

local Methods = vim.lsp.protocol.Methods

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir, project_type = era.m.lsp.fn.locate_js_project_root(filepath) ---@type string|nil, "deno"|"node"
  if project_type == "node" then
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

  era.m.lsp.event.on_attach(client, bufnr)

  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "gD",
      callback = function()
        client:exec_cmd({
          title = "Go to source definition",
          command = "typescript.goToSourceDefinition",
          arguments = { vim.uri_from_bufnr(bufnr), vim.lsp.util.make_position_params(0, client.offset_encoding).position },
        })
      end,
      desc = "lsp: go to source definition",
    },
    {
      modes = { "n" },
      key = "gR",
      callback = function()
        client:exec_cmd({
          title = "Find all file references",
          command = "typescript.findAllFileReferences",
          arguments = { vim.uri_from_bufnr(bufnr) },
        })
      end,
      desc = "lsp: find all file references",
    },
    {
      modes = { "n" },
      key = "<leader>cV",
      callback = function()
        client:exec_cmd({ title = "Select TypeScript version", command = "typescript.selectTypeScriptVersion" })
      end,
      desc = "lsp: select TypeScript version",
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
  era.m.lsp.event.bindkeys(client, bufnr, keymaps)
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

local paths = {
  vue_ls = era.m.lsp.fn.locate_mason_pkg_path("vue-language-server", "/node_modules/@vue/language-server", true),
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
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "vtsls", "--stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
  init_options = {
    hostInfo = "neovim",
  },
  root_markers = { "tsconfig.json", "package.json", "jsconfig.json", ".git" },
  settings = {
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
      tsdk = yoz.path.locate_nearest(dot.path.cwd(), { dot.path.normalize("node_modules/typescript/lib") }),
      globalTsdk = yoz.path.locate_nearest(dot.path.cwd(), { dot.path.normalize("node_modules/typescript/lib") }),
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
  root_dir = root_dir,
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
