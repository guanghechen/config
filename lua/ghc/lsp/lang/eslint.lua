local get_capabilities = require("ghc.lsp.common").get_capabilities
local handlers = require("ghc.lsp.common").handlers
local locate_lsp_root = require("ghc.lsp.common").locate_lsp_root
local on_init = require("ghc.lsp.common").on_init

---@type string[]
local CONFIG_FILENAMES = {
  "eslint.config.js",
  ".eslintrc",
  ".eslintrc.json",
  ".eslintrc.js",
  ".eslintrc.mjs",
}

return function()
  local capabilities = get_capabilities()

  return {
    capabilities = capabilities,
    handlers = handlers,
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
end
