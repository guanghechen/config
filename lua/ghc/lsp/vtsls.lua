local __module_name__ = "ghc.lsp.vtsls" ---@type string

---@param client                        vim.lsp.Client
---@param bufnr                         integer
---@return nil
local function on_attach(client, bufnr)
  client.commands["_typescript.moveToFileRefactoring"] = function(lsp_command)
    local action, uri, range = table.unpack(lsp_command.arguments)
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

  ---@type eve.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "gD",
      callback = function()
        local params = vim.lsp.util.make_position_params(nil, "utf-8")
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
    {
      modes = { "n" },
      key = "<leader>cr",
      callback = function()
        local old_name = vim.fn.expand("<cword>")
        vim.ui.input({ prompt = "New Name", default = old_name }, function(new_name)
          if new_name == nil or old_name == new_name then
            return
          end

          vim.api.nvim_feedkeys("l", "n", false)

          local params = vim.lsp.util.make_position_params(nil, "utf-8")
          params.position.character = params.position.character + 1
          params.newName = new_name

          vim.lsp.buf_request(bufnr, "textDocument/rename", params, function(err, result, ctx, config)
            if err then
              eve.reporter.error({
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

local plugins = {
  vue = eve.lsp.locate_mason_pkg_path("vue-language-server", "/node_modules/@vue/language-server", true),
}

local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_attach = on_attach,
  on_init = eve.lsp.on_init,
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "vue",
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
        tsdk = eve.path.locate_nearest_filepath(eve.path.cwd(), { eve.path.normalize("node_modules/typescript/lib") }),
        globalTsdk = eve.path.locate_nearest_filepath(
          eve.path.cwd(),
          { eve.path.normalize("node_modules/typescript/lib") }
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
}
