-- https://github.com/neovim/nvim-lspconfig/blob/4d3b3bb8815fbe37bcaf3dbdb12a22382bc11ebe/doc/configs.md#vtsls
local __module_name__ = "lsp.vtsls" ---@type string

---@type string[]
local CONFIG_FILENAMES = {
  "package.json",
  "tsconfig.json",
  "jsconfig.json",
}

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
      client:request("workspace/executeCommand", {
        command = lsp_command.command,
        arguments = { action, uri, range, new_filename },
      })
    end

    local fname = vim.uri_to_fname(uri)
    client:request("workspace/executeCommand", {
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
    {
      modes = { "n" },
      key = "<leader>cr",
      callback = function()
        local old_name = vim.fn.expand("<cword>")
        local winnr = vim.api.nvim_get_current_win() ---@type integer
        vim.ui.input({ prompt = "New Name", default = old_name }, function(new_name)
          if new_name == nil or old_name == new_name then
            return
          end

          vim.api.nvim_feedkeys("l", "n", false)

          local params = vim.lsp.util.make_position_params(winnr, "utf-8")
          params.position.character = params.position.character + 1
          ---@diagnostic disable-next-line: inject-field
          params.newName = new_name

          vim.lsp.buf_request(bufnr, "textDocument/rename", params, function(err, result, ctx, config)
            if err then
              std.reporter.error({
                from = __module_name__,
                subject = "rename",
                message = "Failed to rename.",
                details = { err = err, result = result, ctx = ctx, config = config },
              })
              return
            end
            vim.lsp.handlers["textDocument/rename"](err, result, ctx, config)
          end)
        end)
      end,
      desc = "lsp: rename",
    },
  }
  eve.nvim.bindkeys(keymaps, { bufnr = bufnr })
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir = eve.lsp.locate_lsp_root(filename, CONFIG_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

local plugins = {
  vue = eve.lsp.locate_mason_pkg_path("vue-language-server", "/node_modules/@vue/language-server", true),
}

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
    "vue",
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
          globalPlugins = vim.tbl_filter(function(v)
            return not not v
          end, {
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
        tsdk = std.path.locate_nearest_filepath(std.path.cwd(), { std.path.normalize("node_modules/typescript/lib") }),
        globalTsdk = std.path.locate_nearest_filepath(
          std.path.cwd(),
          { std.path.normalize("node_modules/typescript/lib") }
        ),
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
  on_init = on_init,
}
