local __module_name__ = "era.m.lsp" ---@type string

---@class era.m.lsp.__mods
local __mods = {
  action = "era.m.lsp.action",
  diagnostic = "era.m.lsp.diagnostic",
  event = "era.m.lsp.event",
  fn = "era.m.lsp.fn",
  reference = "era.m.lsp.reference",
}

---@class era.m.lsp
---@field public __mods                 era.m.lsp.__mods
---@field public action                 era.m.lsp.action
---@field public diagnostic             era.m.lsp.diagnostic
---@field public event                  era.m.lsp.event
---@field public fn                     era.m.lsp.fn
---@field public reference              era.m.lsp.reference
local M = setmetatable({
  __mods = __mods,
}, {
  __index = function(t, k)
    local m = __mods[k] ---@type string|nil
    if m == nil then
      return rawget(t, k)
    end
    return require(m)
  end,
})

----------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------

---@return nil
function M.dressing()
  M.diagnostic.setup()
  vim.lsp.buf.code_action = M.action.code_action

  vim.api.nvim_create_autocmd("FileType", {
    group = stl.nvim.fn.augroup(__module_name__ .. ".dressing"),
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
end

return M
