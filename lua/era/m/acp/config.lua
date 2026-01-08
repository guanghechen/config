---@alias era.m.acp.ProviderName "claude"|"codex"|"gemini"|"opencode"

---@class era.m.acp.IProviderConfig
---@field public name                   era.m.acp.ProviderName
---@field public label                  string
---@field public model                  string
---@field public desc                   string

---@class era.m.acp.config
local M = {}

---@type era.m.acp.ProviderName[]
M.providers = { "claude", "codex", "gemini", "opencode" }

---@type era.m.acp.ProviderName
M.default_provider = "claude"

---@type table<era.m.acp.ProviderName, era.m.acp.IProviderConfig>
M.provider_configs = {
  claude = {
    name = "claude",
    label = "Claude Code",
    model = "claude-sonnet-4",
    desc = "Anthropic Claude via CLI",
  },
  codex = {
    name = "codex",
    label = "Codex",
    model = "gpt-4.1",
    desc = "OpenAI Codex via ACP",
  },
  gemini = {
    name = "gemini",
    label = "Gemini CLI",
    model = "gemini-2.5-pro",
    desc = "Google Gemini via ACP",
  },
  opencode = {
    name = "opencode",
    label = "OpenCode",
    model = "configurable",
    desc = "OpenCode Agent via ACP",
  },
}

---@type string
M.system_prompt = [[You are a helpful AI coding assistant integrated into Neovim. You help users with code editing, debugging, and understanding their codebase.

Always be concise and focus on the task at hand.]]

return M
