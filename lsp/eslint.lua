-- https://github.com/neovim/nvim-lspconfig/blob/4d3b3bb8815fbe37bcaf3dbdb12a22382bc11ebe/doc/configs.md#eslint

---@type string[]
local CONFIG_FILENAMES = {
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
  eve.lsp.before_init(params, config)

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
      if vim.fn.filereadable(root_dir .. "/" .. file) == 1 then
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
  eve.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

---@param bufnr                         integer
---@param on_dir                        fun(rootdir: string|nil)
local function root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local rootdir = eve.lsp.locate_lsp_root(filename, CONFIG_FILENAMES) ---@type string|nil
  on_dir(rootdir)
end

return {
  capabilities = eve.lsp.get_capabilities(),
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
      vim.notify("[lspconfig] ESLint probe failed.", vim.log.levels.WARN)
      return {}
    end,
    ["eslint/noLibrary"] = function()
      vim.notify("[lspconfig] Unable to find ESLint library.", vim.log.levels.WARN)
      return {}
    end,
  },
  workspace_required = true,
  settings = {
    validate = "on",
    packageManager = nil,
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
  on_init = on_init,
}
