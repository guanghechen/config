local get_capabilities = require("ghc.lsp.common").get_capabilities
local handlers = require("ghc.lsp.common").handlers
local locate_lsp_root = require("ghc.lsp.common").locate_lsp_root
local on_init = require("ghc.lsp.common").on_init

---@type string[]
local CONFIG_FILENAMES = {
  "tailwind.config.ts",
  "tailwind.config.js",
  "tailwind.config.mjs",
  "vite.config.ts",
}

return function()
  local capabilities = get_capabilities()

  ---@return string|nil
  local function detectLspServer()
    local _, binPath = locate_lsp_root(
      eve.path.cwd() .. eve.env.PATH_SEP .. "a.css",
      { "./node_modules/.bin/tailwindcss-language-server" }
    )
    if binPath ~= nil and vim.fn.executable(binPath) == 1 then
      return binPath
    end
    return nil
  end

  local lspBinPath = detectLspServer()
  eve.debug.log({ lspBinPath = lspBinPath })

  return {
    capabilities = capabilities,
    handlers = handlers,
    on_init = on_init,
    filetypes_exclude = { "markdown" },
    filetypes_include = { "css", "javascriptreact", "javascript.jsx", "typescriptreact", "typescript.tsx" },
    cmd = lspBinPath and { lspBinPath, "--stdio" } or nil,
    root_dir = function(filename)
      return locate_lsp_root(filename, CONFIG_FILENAMES)
    end,
    settings = {
      tailwindCSS = {
        includeLanguages = {
          elixir = "html-eex",
          eelixir = "html-eex",
          heex = "html-eex",
        },
      },
    },
  }
end
