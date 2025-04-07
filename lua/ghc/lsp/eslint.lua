---@type string[]
local CONFIG_FILENAMES = {
  "eslint.config.js",
  ".eslintrc",
  ".eslintrc.json",
  ".eslintrc.js",
  ".eslintrc.mjs",
}

local capabilities = eve.lsp.get_capabilities()

return {
  capabilities = capabilities,
  on_init = eve.lsp.on_init,
  root_dir = function(filename)
    return eve.lsp.locate_lsp_root(filename, CONFIG_FILENAMES)
  end,
  settings = {
    eslint = {
      workingDirectories = { mode = "auto" },
    },
  },
}
