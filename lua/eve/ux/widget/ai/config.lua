---@class eve.ux.widget.ai.config
local M = {}

---@type eve.ux.widget.ai.AgentName[]
M.agents = { "claude", "codex", "copilot", "gemini" }

---@type table<eve.ux.widget.ai.AgentName, string>
M.agent_labels = {
  claude = "claude",
  codex = "codex",
  copilot = "copilot",
  gemini = "gemini",
}

---@type table<eve.ux.widget.ai.AgentName, eve.ux.widget.ai.IToolConfig>
M.tools = {
  claude = {
    cmd = "claude",
    args = function()
      return { "--dangerously-skip-permissions" }
    end,
    env = function()
      return { CLAUDE_CONFIG_DIR = vim.env.CLAUDE_CONFIG_DIR }
    end,
    proc_pattern = "\\<claude\\>",
    url = "https://github.com/anthropics/claude-code",
  },
  codex = {
    cmd = "codex",
    args = function(cwd)
      return { "--cd", cwd, "--dangerously-bypass-approvals-and-sandbox" }
    end,
    env = function()
      return { CODEX_HOME = vim.env.CODEX_HOME }
    end,
    proc_pattern = "\\<codex\\>",
    url = "https://github.com/openai/codex",
  },
  copilot = {
    cmd = "copilot",
    args = function()
      return { "--banner" }
    end,
    env = function()
      return {}
    end,
    proc_pattern = "\\<copilot\\>",
    url = "https://github.com/github/copilot-cli",
  },
  gemini = {
    cmd = "gemini",
    args = function()
      return {}
    end,
    env = function()
      return {}
    end,
    proc_pattern = "\\<gemini\\>",
    url = "https://github.com/google-gemini/gemini-cli",
  },
}

return M
