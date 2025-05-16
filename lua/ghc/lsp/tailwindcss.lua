---@type string[]
local CONFIG_FILENAMES = {
  "tailwind.config.ts",
  "tailwind.config.js",
  "tailwind.config.mjs",
  "vite.config.ts",
}

local capabilities = eve.lsp.get_capabilities()

---@return string|nil
local function detectLspServer()
  local _, binPath = eve.lsp.locate_lsp_root(
    std.path.cwd() .. std.env.PATH_SEP .. "a.css",
    { "./node_modules/.bin/tailwindcss-language-server" }
  )
  if binPath ~= nil and vim.fn.executable(binPath) == 1 then
    return binPath
  end
  return nil
end

local lspBinPath = detectLspServer()

return {
  capabilities = capabilities,
  on_init = eve.lsp.on_init,
  filetypes_exclude = { "markdown" },
  filetypes_include = { "css", "javascriptreact", "javascript.jsx", "typescriptreact", "typescript.tsx" },
  cmd = lspBinPath and { lspBinPath, "--stdio" } or nil,
  root_dir = function(filename)
    return eve.lsp.locate_lsp_root(filename, CONFIG_FILENAMES)
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
