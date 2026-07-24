local __module_name__ = "lsp.eslint" ---@type string

-- https://github.com/neovim/nvim-lspconfig/blob/78596b61676d361a74ea3f3abbbf83d5fe6f5519/lsp/eslint.lua
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

---@param params                        lsp.InitializeParams
---@param config                        any
local function before_init(params, config)
  era.m.lsp.event.before_init(params, config)

  -- The "workspaceFolder" is a VSCode concept. It limits how far the server will traverse the
  -- file system when locating the ESLint config file (e.g., .eslintrc).
  local root_dir = config.root_dir

  if root_dir then
    config.settings = config.settings or {}
    config.settings.workspaceFolder = {
      uri = vim.uri_from_fname(root_dir),
      name = vim.fn.fnamemodify(root_dir, ":t"),
    }

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

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  era.m.lsp.event.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  era.m.lsp.event.on_init(client, config)
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  -- exclude deno
  if vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" }) then
    return
  end

  local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir = era.m.lsp.fn.locate_lsp_root(filename, CONFIG_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

---@type vim.lsp.Config
return {
  capabilities = era.m.lsp.event.get_capabilities(),
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
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
  on_detach = on_detach,
  on_init = on_init,
}
