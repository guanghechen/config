---@class ghc.action.mason
local M = {}

---@return string[]
function M.get_mason_ensure_installed()
  return {
    -- lsp --
    "bash-language-server", -- bashls
    -- "clangd", -- clangd
    "copilot-language-server", -- copilot
    "css-lsp", -- cssls
    "dockerfile-language-server", -- docker
    "docker-compose-language-service", -- docker_compose_language_service
    "eslint-lsp", -- eslint
    "html-lsp", -- html
    "json-lsp", -- jsonls
    "lua-language-server", -- lua_ls
    "pyright", -- pyright
    -- "basedpyright",
    "rust-analyzer", -- rust_analyzer
    -- "sqls", -- sqls
    "tailwindcss-language-server", --  tailwindcss
    "taplo", -- taplo
    "vtsls", -- vtsls
    "vetur-vls", -- vuels
    "yaml-language-server", -- yamlls

    -- dap --
    "js-debug-adapter",

    -- lint --
    "cspell",
    "ruff",

    -- formatter --
    "black",
    "isort",
    "prettier",
    "shfmt",
    "stylelint",
    "stylua",

    -- utilities --
    "tree-sitter-cli",
  }
end

---@param packages                      string[]
---@param force                         boolean
---@param on_close                      fun(): nil
function M.install(packages, force, on_close)
  if not force then
    local mr = require("mason-registry")
    local all_packages = vim.list_slice(packages) ---@type string[]
    packages = {} ---@type string[]
    for _, pkg in ipairs(all_packages) do
      local p = mr.get_package(pkg)
      if not p:is_installed() then
        table.insert(packages, pkg)
      end
    end
  end

  local count = #packages
  if count < 1 then
    on_close()
    return
  end

  local mr = require("mason-registry")
  for _, pkg in ipairs(packages) do
    local p = mr.get_package(pkg)
    local handle = p:install()
    handle:once("closed", function()
      count = count - 1
      if count < 1 then
        on_close()
      end
    end)
  end
end

---@param force                         boolean
---@param on_close                      fun(): nil
---@return nil
function M.install_all(force, on_close)
  require("mason.ui").open()
  local packages = M.get_mason_ensure_installed() ---@type string[]
  M.install(packages, force, on_close)
end

return M
