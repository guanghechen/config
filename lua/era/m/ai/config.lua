---@class era.m.ai.config
local M = {}

---@type era.m.ai.AgentName[]
M.agents = { "claude", "codex", "copilot", "gemini", "opencode" }

---@type table<era.m.ai.AgentName, string>
M.agent_labels = {
  claude = "claude",
  codex = "codex",
  copilot = "copilot",
  gemini = "gemini",
  opencode = "opencode",
}

---@type table<era.m.ai.AgentName, era.m.ai.IToolConfig>
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
    vim_mode = true,
    insert_pattern = "%-%- INSERT %-%-",
    -- The spinner's trailing ellipsis is the stable busy marker (e.g.
    -- "✶ Composing… (3s · thinking…)"). Unanchored and word-final so it also catches
    -- multi-word states ("Compacting conversation…") that a leading "^<glyph> <word>…"
    -- shape misses — a miss there would let us Escape a still-generating agent. The
    -- ellipsis-less idle footer and the persistent "Crunched for Ns" summary do not match.
    busy_pattern = "%a+…",
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
    vim_mode = false,
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
    vim_mode = false,
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
    vim_mode = true,
  },
  opencode = {
    cmd = "opencode",
    args = function()
      return {}
    end,
    env = function()
      return {}
    end,
    proc_pattern = "\\<opencode\\>",
    url = "https://github.com/sst/opencode",
    vim_mode = false,
  },
}

return M
