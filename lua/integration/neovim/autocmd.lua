---@type table<string, string[]>
local ft_to_lsp_map = {
  astro = { "eslint" },
  bash = { "bashls" },
  c = { "clangd" },
  cpp = { "clangd" },
  css = { "cssls", "tailwindcss" },
  cuda = { "clangd" },
  dockerfile = { "dockerls" },
  excalidraw = { "jsonls" },
  handlebars = { "tailwindcss" },
  hbs = { "tailwindcss" },
  html = { "html", "tailwindcss" },
  htmlangular = { "eslint" },
  javascript = { "vtsls", "eslint", "tailwindcss" },
  javascriptreact = { "vtsls", "eslint", "tailwindcss" },
  ["javascript.jsx"] = { "vtsls", "eslint", "tailwindcss" },
  json = { "jsonls" },
  jsonc = { "jsonls" },
  less = { "cssls", "tailwindcss" },
  lua = { "lua_ls" },
  mdx = { "tailwindcss" },
  objc = { "clangd" },
  objcpp = { "clangd" },
  postcss = { "tailwindcss" },
  python = { "basedpyright", "ruff" },
  rust = { "rust_analyzer" },
  sass = { "tailwindcss" },
  scss = { "cssls", "tailwindcss" },
  sh = { "bashls" },
  stylus = { "tailwindcss" },
  svelte = { "eslint", "tailwindcss" },
  templ = { "html" },
  toml = { "taplo" },
  typescript = { "vtsls", "eslint", "tailwindcss" },
  typescriptreact = { "vtsls", "eslint", "tailwindcss" },
  ["typescript.tsx"] = { "vtsls", "eslint", "tailwindcss" },
  vue = { "vue_ls", "eslint", "tailwindcss" },
  yaml = { "yamlls" },
  ["yaml.docker-compose"] = { "yamlls", "docker_compose_language_service" },
  ["yaml.gitlab"] = { "yamlls" },
  ["yaml.helm-values"] = { "yamlls" },
}

---@type table<string, true>
local enabled_lsp_set = {}

--lsp_setup---------------------------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  group = ark.nvim.augroup("lsp_setup"),
  callback = function(args)
    local ft = args.match ---@type string
    local lsp_servers = ft_to_lsp_map[ft]
    if lsp_servers then
      for _, lsp in ipairs(lsp_servers) do
        if not enabled_lsp_set[lsp] then
          enabled_lsp_set[lsp] = true
          vim.lsp.enable(lsp)
        end
      end
    end
  end,
})
