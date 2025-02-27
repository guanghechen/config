local get_capabilities = require("ghc.lsp.common").get_capabilities
local handlers = require("ghc.lsp.common").handlers
local basic_on_attach = require("ghc.lsp.common").on_attach
local on_init = require("ghc.lsp.common").on_init

---@class ghc.lsp.lang.python
local M = {}

function M.pyright()
  local capabilities = get_capabilities()

  return {
    capabilities = capabilities,
    handlers = handlers,
    on_attach = basic_on_attach,
    on_init = on_init,
    settings = {
      pyright = {
        enabled = true,
      },
    },
  }
end

function M.ruff()
  local capabilities = get_capabilities()

  local function on_attach(client, bufnr)
    client.server_capabilities.hoverProvider = false
    basic_on_attach(client, bufnr)
  end

  return {
    capabilities = capabilities,
    handlers = handlers,
    on_attach = on_attach,
    on_init = on_init,
    settings = {
      ruff = {
        cmd_env = { RUFF_TRACE = "messages" },
        init_options = {
          settings = {
            logLevel = "error",
          },
        },
        keys = {
          {
            "<leader>co",
            function()
              vim.lsp.buf.code_action({
                apply = true,
                context = {
                  only = { "source.organizeImports" },
                  diagnostics = {},
                },
              })
            end,
            desc = "Organize Imports",
          },
        },
      },
    },
  }
end

return M
