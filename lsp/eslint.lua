local __module_name__ = "lsp.eslint" ---@type string

-- https://github.com/neovim/nvim-lspconfig/blob/78174f395e705de97d1329c18394831737d9a4b4/lsp/eslint.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#eslint

---@type string[]
local CONFIG_FILENAMES = {
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
  "bun.lockb",
  "bun.lock",
  "eslint.config.js",
  "eslint.config.ts",
  "eslint.config.mjs",
  "eslint.config.cjs",
  ".eslintrc",
  ".eslintrc.json",
  ".eslintrc.js",
  ".eslintrc.mjs",
}

local FLAT_CONFIG_FILENAMES = {
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
}

---@param params                        lsp.InitializeParams
---@param config                        any
local function before_init(params, config)
  era.lsp.before_init(params, config)

  -- The "workspaceFolder" is a VSCode concept. It limits how far the server will traverse the
  -- file system when locating the ESLint config file (e.g., .eslintrc).
  local root_dir = config.root_dir

  if root_dir then
    config.settings = config.settings or {}
    config.settings.workspaceFolder = {
      uri = root_dir,
      name = vim.fn.fnamemodify(root_dir, ":t"),
    }

    for _, file in ipairs(FLAT_CONFIG_FILENAMES) do
      local found_files = vim.fn.globpath(root_dir, file, true, true)

      -- Filter out files inside node_modules
      local has_inside_node_modules = false
      for _, found_file in ipairs(found_files) do
        if string.find(found_file, "[/\\]node_modules[/\\]") == nil then
          has_inside_node_modules = true
        end
      end
      if has_inside_node_modules then
        config.settings.experimental = config.settings.experimental or {}
        config.settings.experimental.useFlatConfig = true
        break
      end
    end

    -- Support Yarn2 (PnP) projects
    local pnp_cjs = root_dir .. "/.pnp.cjs"
    local pnp_js = root_dir .. "/.pnp.js"
    if vim.uv.fs_stat(pnp_cjs) or vim.uv.fs_stat(pnp_js) then
      local cmd = config.cmd
      config.cmd = vim.list_extend({ "yarn", "exec" }, cmd)
    end
  end
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  era.lsp.on_attach(client, bufnr)

  vim.api.nvim_buf_create_user_command(0, "LspEslintFixAll", function()
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

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  era.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  era.lsp.on_init(client, config)
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir = era.lsp.locate_lsp_root(filename, CONFIG_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

---@type vim.lsp.Config
return {
  capabilities = era.lsp.get_capabilities(),
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "vue",
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
      ark.reporter.warn({
        from = __module_name__,
        subject = "probeFailed",
        message = "ESLint probe failed.",
      })
      return {}
    end,
    ["eslint/noLibrary"] = function()
      ark.reporter.warn({
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
    experimental = {
      useFlatConfig = false,
    },
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
    workingDirectory = { mode = "location" },
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
  on_detach = on_detach,
  on_init = on_init,
}
