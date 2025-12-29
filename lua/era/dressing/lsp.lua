local __module_name__ = "era.dressing.lsp" ---@type string

---@type table<string, string[]>
local ft_to_lsp_map = {
  astro = { "eslint", "emmet_language_server" },
  bash = { "bashls" },
  c = { "clangd" },
  cpp = { "clangd" },
  css = { "cssls", "tailwindcss", "emmet_language_server" },
  cuda = { "clangd" },
  dockerfile = { "dockerls" },
  excalidraw = { "jsonls" },
  handlebars = { "tailwindcss" },
  hbs = { "tailwindcss" },
  html = { "html", "tailwindcss", "emmet_language_server" },
  htmlangular = { "eslint" },
  javascript = { "vtsls", "eslint", "tailwindcss" },
  javascriptreact = { "vtsls", "eslint", "tailwindcss", "emmet_language_server" },
  ["javascript.jsx"] = { "vtsls", "eslint", "tailwindcss" },
  json = { "jsonls" },
  jsonc = { "jsonls" },
  less = { "cssls", "tailwindcss", "emmet_language_server" },
  lua = { "lua_ls" },
  mdx = { "tailwindcss" },
  objc = { "clangd" },
  objcpp = { "clangd" },
  postcss = { "tailwindcss" },
  python = { "basedpyright", "ruff" },
  rust = { "rust_analyzer" },
  sass = { "tailwindcss", "emmet_language_server" },
  scss = { "cssls", "tailwindcss", "emmet_language_server" },
  sh = { "bashls" },
  stylus = { "tailwindcss" },
  svelte = { "eslint", "tailwindcss", "emmet_language_server" },
  templ = { "html" },
  toml = { "taplo" },
  typescript = { "vtsls", "eslint", "tailwindcss" },
  typescriptreact = { "vtsls", "eslint", "tailwindcss", "emmet_language_server" },
  ["typescript.tsx"] = { "vtsls", "eslint", "tailwindcss" },
  vue = { "vue_ls", "eslint", "tailwindcss", "emmet_language_server" },
  yaml = { "yamlls" },
  ["yaml.docker-compose"] = { "yamlls", "docker_compose_language_service" },
  ["yaml.gitlab"] = { "yamlls" },
  ["yaml.helm-values"] = { "yamlls" },
}

---@type table<string, true>
local enabled_lsp_set = {}

---@param ft                            string
---@return nil
local function enable_lsp_for_filetype(ft)
  local lsp_servers = ft_to_lsp_map[ft]
  if lsp_servers == nil then
    return
  end

  for _, lsp in ipairs(lsp_servers) do
    if not enabled_lsp_set[lsp] then
      enabled_lsp_set[lsp] = true
      vim.lsp.enable(lsp)
    end
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = stl.nvim.fn.augroup(__module_name__ .. ".setup"),
  callback = function(args)
    enable_lsp_for_filetype(args.match)
  end,
})

for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    local ft = vim.bo[bufnr].filetype ---@type string
    if ft ~= "" then
      enable_lsp_for_filetype(ft)
    end
  end
end

