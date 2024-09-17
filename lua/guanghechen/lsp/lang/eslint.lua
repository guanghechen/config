local on_attach = require("guanghechen.lsp.common").on_attach
local on_init = require("guanghechen.lsp.common").on_init
local capabilities = require("guanghechen.lsp.common").capabilities
local locate_lsp_root = require("guanghechen.lsp.common").locate_lsp_root

---@type string[]
local CONFIG_FILENAMES = {
  "eslint.config.js",
  ".eslintrc",
  ".eslintrc.json",
  ".eslintrc.js",
  ".eslintrc.mjs",
}

return {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  root_dir = function(filename)
    return locate_lsp_root(filename, CONFIG_FILENAMES)
  end,
  settings = {
    eslint = {
      workingDirectories = { mode = "auto" },
    },
  },
}
