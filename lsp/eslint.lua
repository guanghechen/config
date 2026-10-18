local __module_name__ = "lsp.eslint" ---@type string

-- Upstream reference: https://github.com/neovim/nvim-lspconfig/blob/ac062d0d01c019c0dbdb798968f3e5d8b35c3853/lsp/eslint.lua
-- Derived from nvim-lspconfig (Apache-2.0); license in lua/era/m/lsp/init.lua.
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#eslint

---@type string[]
local ROOT_FILENAMES = {
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
  "bun.lockb",
  "bun.lock",
}

---@type string[]
local CONFIG_FILENAMES = {
  "eslint.config.js",
  "eslint.config.ts",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.mts",
  "eslint.config.cts",
  ".eslintrc",
  ".eslintrc.json",
  ".eslintrc.js",
  ".eslintrc.mjs",
  ".eslintrc.cjs",
  ".eslintrc.yaml",
  ".eslintrc.yml",
}

vim.list_extend(ROOT_FILENAMES, CONFIG_FILENAMES)

---@param _                             lsp.InitializeParams
---@param config                        any
---@return nil
local function before_init(_, config)
  -- The "workspaceFolder" is a VSCode concept. It limits how far the server will traverse the
  -- file system when locating the ESLint config file (e.g., .eslintrc).
  local root_dir = config.root_dir

  if root_dir then
    config.settings = config.settings or {}
    config.settings.workspaceFolder = {
      uri = vim.uri_from_fname(root_dir),
      name = vim.fn.fnamemodify(root_dir, ":t"),
    }
  end
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.m.lsp.event.on_attach(client, bufnr)

  vim.api.nvim_buf_create_user_command(bufnr, "LspEslintFixAll", function()
    client:request_sync("workspace/executeCommand", {
      command = "eslint.applyAllFixes",
      arguments = {
        {
          uri = vim.uri_from_bufnr(bufnr),
          version = vim.lsp.util.buf_versions[bufnr],
        },
      },
    }, nil, bufnr)
  end, {})
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
---@return nil
local function root_dir(bufnr, on_dir)
  -- exclude deno
  if vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" }) then
    return
  end

  local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
  if vim.fs.root(bufnr, { "biome.json", "biome.jsonc" }) then
    -- Keep explicit ESLint configurations during migration; a lockfile alone is not an opt-in.
    local eslint_config = vim.fs.find(function(name, dir)
      if vim.list_contains(CONFIG_FILENAMES, name) then
        local stat = vim.uv.fs_stat(dir .. "/" .. name)
        return stat ~= nil and stat.type == "file"
      end
      if name == "package.json" then
        local package_json = stl.fs.read_json({
          filepath = dir .. "/" .. name,
          silent_on_bad_json = true,
          silent_on_bad_path = true,
        })
        return type(package_json) == "table" and type(package_json.eslintConfig) == "table"
      end
      return false
    end, { path = vim.fs.dirname(filename), upward = true })[1]
    if eslint_config == nil then
      return
    end
    on_dir(era.m.lsp.fn.locate_lsp_root(filename, ROOT_FILENAMES) or vim.fs.dirname(eslint_config))
    return
  end

  local rootdir = era.m.lsp.fn.locate_lsp_root(filename, ROOT_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = function(dispatchers, config)
    local command = config.root_dir and era.m.lsp.fn.locate_node_bin(config.root_dir, "vscode-eslint-language-server")
      or "vscode-eslint-language-server"
    return vim.lsp.rpc.start({ command, "--stdio" }, dispatchers, { cwd = config.root_dir })
  end,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "svelte",
    "astro",
    "htmlangular",
  },
  handlers = {
    ["eslint/openDoc"] = function(_, result)
      if result then
        vim.ui.open(result.url)
      end
      return {}
    end,
    ["eslint/confirmESLintExecution"] = function(_, result)
      if not result then
        return
      end
      return 4 -- approved
    end,
    ["eslint/probeFailed"] = function()
      stl.reporter.warn({
        from = __module_name__,
        subject = "probeFailed",
        message = "ESLint probe failed.",
      })
      return {}
    end,
    ["eslint/noLibrary"] = function()
      stl.reporter.warn({
        from = __module_name__,
        subject = "noLibrary",
        message = "Unable to find ESLint library.",
      })
      return {}
    end,
  },
  workspace_required = true,
  settings = {
    validate = "on",
    packageManager = vim.NIL,
    useESLintClass = false,
    experimental = {},
    codeActionOnSave = {
      enable = false,
      mode = "all",
    },
    format = true,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = {
      shortenToSingleLine = false,
    },
    -- nodePath configures the directory in which the eslint server should start its node_modules resolution.
    -- This path is relative to the workspace folder (root dir) of the server instance.
    nodePath = "",
    workingDirectory = { mode = "auto" },
    codeAction = {
      disableRuleComment = {
        enable = true,
        location = "separateLine",
      },
      showDocumentation = {
        enable = true,
      },
    },
  },
  before_init = before_init,
  root_dir = root_dir,
  on_attach = on_attach,
}
