-- https://github.com/neovim/nvim-lspconfig/blob/c30a661a1f4c270f542eaf861f3eb726bb9baa69/lsp/yamlls.lua
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#yamlls

---@param params                        lsp.InitializeParams
---@param config                        table
local function before_init(params, config)
  eve.lsp.before_init(params, config)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_attach(client, bufnr)
  eve.lsp.on_attach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param bufnr                         integer
local function on_detach(client, bufnr)
  eve.lsp.on_detach(client, bufnr)
end

---@param client                        vim.lsp.Client
---@param config                        any
local function on_init(client, config)
  eve.lsp.on_init(client, config)
end

return {
  capabilities = eve.lsp.get_capabilities(),
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" },
  root_markers = { ".git" },
  settings = {
    redhat = { telemetry = { enabled = false } },
    yaml = {
      keyOrdering = false,
      format = {
        enable = true,
      },
      validate = true,
      schemaStore = {
        -- Must disable built-in schemaStore support to use customized schemas
        enable = false,
        -- Avoid TypeError: Cannot read properties of undefined (reading 'length')
        url = "",
      },
      schemas = {
        {
          description = "GitHub Action's dependabot.yml files",
          fileMatch = { "**/.github/dependabot.yml", "**/.github/dependabot.yaml" },
          name = "dependabot-v2.json",
          url = "https://www.schemastore.org/dependabot-2.0.json",
        },
        {
          description = "A bot that helps onboarding new open-source contributors",
          fileMatch = { "**/.github/first-timers.yml" },
          name = "first-timers-bot",
          url = "https://www.schemastore.org/first-timers.json",
        },
        {
          description = "YAML GitHub Discussions",
          fileMatch = { "**/.github/DISCUSSION_TEMPLATE/*.yml", "**/.github/DISCUSSION_TEMPLATE/*.yaml" },
          name = "GitHub Discussion",
          url = "https://www.schemastore.org/github-discussion.json",
        },
        {
          description = "YAML GitHub Funding",
          fileMatch = {
            "**/.github/FUNDING.yml",
            "**/.github/FUNDING.yaml",
            "**/.github/funding.yml",
            "**/.github/funding.yaml",
          },
          name = "GitHub Funding",
          url = "https://www.schemastore.org/github-funding.json",
        },
        {
          description = "YAML configuring GitHub Issue Templates",
          fileMatch = { "**/.github/ISSUE_TEMPLATE/config.yml", "**/.github/ISSUE_TEMPLATE/config.yaml" },
          name = "GitHub Issue Template configuration",
          url = "https://www.schemastore.org/github-issue-config.json",
        },
        {
          description = "YAML GitHub issue forms",
          fileMatch = { "**/.github/ISSUE_TEMPLATE/**.yml", "**/.github/ISSUE_TEMPLATE/**.yaml" },
          name = "GitHub Issue Template forms",
          url = "https://www.schemastore.org/github-issue-forms.json",
        },
        {
          description = "YAML GitHub Workflow",
          fileMatch = {
            "**/.github/workflows/*.yml",
            "**/.github/workflows/*.yaml",
            "**/.gitea/workflows/*.yml",
            "**/.gitea/workflows/*.yaml",
            "**/.forgejo/workflows/*.yml",
            "**/.forgejo/workflows/*.yaml",
          },
          name = "GitHub Workflow",
          url = "https://www.schemastore.org/github-workflow.json",
        },
        {
          description = "properties json file for a GitHub Workflow template",
          fileMatch = { "**/.github/workflow-templates/**.properties.json" },
          name = "GitHub Workflow Template Properties",
          url = "https://www.schemastore.org/github-workflow-template-properties.json",
        },
        {
          description = "YAML GitHub automatically generated release notes config",
          fileMatch = { "**/.github/release.yml" },
          name = "GitHub automatically generated release notes configuration",
          url = "https://www.schemastore.org/github-release-config.json",
        },
        {
          description = "A the configuration of the Label Commenter GitHub Action",
          fileMatch = { "**/.github/label-commenter-config.yml" },
          name = "label-commenter-config.yml",
          url = "https://www.schemastore.org/label-commenter-config.json",
        },
        {
          description = "Mergify configuration file",
          fileMatch = { ".mergify.yml", "**/.github/mergify.yml", "**/.mergify/config.yml" },
          name = "Mergify Configuration",
          url = "https://raw.githubusercontent.com/Mergifyio/docs/main/public/mergify-configuration-schema.json",
        },
        {
          description = "Mergify configuration file",
          fileMatch = { ".mergify.yml", "**/.github/mergify.yml", "**/.mergify/config.yml" },
          name = "Mergify Configuration",
          url = "https://raw.githubusercontent.com/Mergifyio/docs/main/public/mergify-configuration-schema.json",
        },
        {
          description = "Configuration file for Stale for closing abandoned issues and pull requests. Documentation: https://probot.github.io/apps/stale/",
          fileMatch = { "**/.github/stale.yml" },
          name = "Stale",
          url = "https://www.schemastore.org/stale.json",
        },
        {
          description = "Release Drafter configuration file",
          fileMatch = { "**/.github/release-drafter.yml" },
          name = "release drafter",
          url = "https://raw.githubusercontent.com/release-drafter/release-drafter/master/schema.json",
        },
        {
          description = "The Compose specification establishes a standard for the definition of multi-container platform-agnostic applications",
          fileMatch = {
            "**/docker-compose.yml",
            "**/docker-compose.yaml",
            "**/docker-compose.*.yml",
            "**/docker-compose.*.yaml",
            "**/compose.yml",
            "**/compose.yaml",
            "**/compose.*.yml",
            "**/compose.*.yaml",
          },
          name = "docker-compose.yml",
          url = "https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json",
        },
        {
          description = "lazydocker settings",
          fileMatch = { "**/lazydocker/config.yml" },
          name = "lazydocker",
          url = "https://www.schemastore.org/lazydocker.json",
        },
        {
          description = "lazygit settings",
          fileMatch = { "**/lazygit/config.yml", "lazygit.yml", ".lazygit.yml" },
          name = "lazygit",
          url = "https://raw.githubusercontent.com/jesseduffield/lazygit/master/schema/config.json",
        },
      },
    },
  },
  before_init = before_init,
  on_attach = on_attach,
  on_detach = on_detach,
  on_init = on_init,
}
