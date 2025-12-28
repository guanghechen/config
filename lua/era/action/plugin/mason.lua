local __module_name__ = "era.action.plugin.mason" ---@type string

---@class era.action.plugin.mason
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
    "emmet-language-server", -- emmet_language_server
    "docker-compose-language-service", -- docker_compose_language_service
    "eslint-lsp", -- eslint
    "html-lsp", -- html
    "json-lsp", -- jsonls
    "lua-language-server", -- lua_ls
    -- "pyright", -- pyright
    "basedpyright", -- basedpyright
    "rust-analyzer", -- rust_analyzer
    -- "sqls", -- sqls
    "tailwindcss-language-server", --  tailwindcss
    "taplo", -- taplo
    "vtsls", -- vtsls
    "vue-language-server", -- vue_ls
    "yaml-language-server", -- yamlls

    -- dap --
    "js-debug-adapter",

    -- lint --
    "cspell",
    "ruff",
    "shellcheck",

    -- formatter --
    "black",
    "isort",
    "prettier",
    "shfmt",
    "stylelint",
    "stylua",

    -- utilities --
    -- "tree-sitter-cli",
  }
end

---@param packages                      string[]
---@param force                         boolean
---@param on_close                      fun(): nil
local function do_install(packages, force, on_close)
  local mr = require("mason-registry")
  local to_install = {} ---@type string[]
  local invalid_packages = {} ---@type string[]

  for _, pkg_name in ipairs(packages) do
    if not mr.has_package(pkg_name) then
      table.insert(invalid_packages, pkg_name)
    elseif force then
      table.insert(to_install, pkg_name)
    else
      local p = mr.get_package(pkg_name)
      if not p:is_installed() then
        table.insert(to_install, pkg_name)
      end
    end
  end

  if #invalid_packages > 0 then
    ark.reporter.error({
      from = __module_name__,
      subject = "Invalid packages",
      message = "The following packages do not exist in mason registry",
      details = invalid_packages,
    })
  end

  local count = #to_install
  if count < 1 then
    on_close()
    return
  end

  local install_failed = {} ---@type string[]
  for _, pkg_name in ipairs(to_install) do
    local p = mr.get_package(pkg_name)
    local handle = p:install()
    handle:once("closed", function()
      if not p:is_installed() then
        table.insert(install_failed, pkg_name)
      end
      count = count - 1
      if count < 1 then
        if #install_failed > 0 then
          ark.reporter.error({
            from = __module_name__,
            subject = "Installation failed",
            message = "The following packages failed to install",
            details = install_failed,
          })
        end
        on_close()
      end
    end)
  end
end

---@param packages                      string[]
---@param force                         boolean
---@param on_close                      fun(): nil
function M.install(packages, force, on_close)
  local mr = require("mason-registry")
  mr.refresh(function()
    do_install(packages, force, on_close)
  end)
end

---@param force                         boolean
---@param on_close                      fun(): nil
function M.install_all(force, on_close)
  require("mason.ui").open()
  local packages = M.get_mason_ensure_installed() ---@type string[]
  M.install(packages, force, on_close)
end

return M
