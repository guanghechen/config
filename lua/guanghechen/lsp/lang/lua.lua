local capabilities = require("guanghechen.lsp.common").capabilities
local handlers = require("guanghechen.lsp.common").handlers
local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init

return {
  capabilities = capabilities,
  handlers = handlers,
  on_attach = on_attach,
  on_init = on_init,
  settings = {
    Lua = {
      codeLens = {
        enable = true,
      },
      completion = {
        callSnippet = "Replace",
      },
      diagnostics = {
        enable = true,
        disable = { "different-requires" },
        globals = { "vim" },
        groupFileStatus = {
          ambiguity = "Any",
          await = "Any",
          codestyle = "Any",
          duplicated = "Any",
          global = "Any",
          luadoc = "Any",
          redefined = "Any",
          strict = "Any",
          strong = "Any",
          ["type-check"] = "Any",
          unbalanced = "Any",
          unused = "Any",
        },
      },
      doc = {
        privateName = { "^_" },
      },
      format = {
        enable = true,
        defaultConfig = {
          indent_style = "space",
          indent_size = "2",
        },
      },
      hint = {
        enable = true,
        setType = false,
        paramType = true,
        paramName = "Disable",
        semicolon = "Disable",
        arrayIndex = "Disable",
      },
      runtime = {
        version = "LuaJIT",
      },
      semantic = { enable = false },
      telemetry = { enable = false },
      workspace = {
        library = {
          vim.fn.expand("$VIMRUNTIME/lua"),
          vim.fn.expand("$VIMRUNTIME/lua/vim/lsp"),
          vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy",
          "${3rd}/luv/library",
        },
        checkThirdParty = false,
        maxPreload = 100000,
        preloadFileSize = 10000,
      },
    },
  },
}
