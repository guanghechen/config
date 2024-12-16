local capabilities = require("guanghechen.lsp.common").capabilities
local handlers = require("guanghechen.lsp.common").handlers
local locate_lsp_root = require("guanghechen.lsp.common").locate_lsp_root
local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init

---@type string[]
local CONFIG_FILENAMES = {
  "eslint.config.js",
  ".eslintrc",
  ".eslintrc.json",
  ".eslintrc.js",
  ".eslintrc.mjs",
}

return {
  capabilities = capabilities,
  handlers = handlers,
  on_attach = on_attach,
  on_init = on_init,
  root_dir = function(filename)
    return locate_lsp_root(filename, CONFIG_FILENAMES)
  end,
  settings = {
    eslint = {
      workingDirectories = { mode = "auto" },
    },
  },
}
