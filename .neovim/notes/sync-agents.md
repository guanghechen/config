## Task Details

为 codex / gemini / opencode 也应用上我们的优化，具体地：

1. codex: 同步更新到 ~/.config/codex/ 下
   - CLAUDE.md 同步到 ~/.config/codex/AGENTS.md 下。 
   - commands/ 同步到 ~/.config/codex/prompts/ 下
   - agents/   同步到 ~/.config/codex/agents/ 下

   需要注意的是：

   - codex 不支持 subagents，如果 slash commands 中含有引用 subagent 的描述，轻微修改它，让它“参见 ~/.config/codex/agents/{agent}.md”中的 spec

2. gemini: 同步更新到 ~/.gemini/ 下
   - CLAUDE.md 同步到 ~/.gemini/GEMINI.md 下。 
   - commands/ 同步到 ~/.gemini/commands/ 下
   - agents/   同步到 ~/.gemini/agents/ 下

   需要注意的是：

   - gemini 不支持 subagents，如果 slash commands 中含有引用 subagent 的描述，轻微修改它，让它“参见 ~/.gemini/agents/{agent}.md”中的 spec
   - gemini 使用 toml 而不是 md

3. opencode: 同步更新到 ~/.config/opencode/ 下
   - CLAUDE.md 同步到 ~/.config/opencode/AGENTS.md 下。 
   - commands/ 同步到 ~/.config/opencode/commands/ 下
   - agents/   同步到 ~/.config/opencode/agents/ 下
   - opencode 支持 subagents，通过 `@{agent}` 的方式如 `@coder` 来引用 `coder` subagent

等所有的同步完成后，依次进入 codex / gemini / opencode 的配置目录进行提交，提交遵循我们的 /commit (commands/commit.md) 的规范

## Hints

1. claude code 支持 subagents，不过引用的时候是通过 `@agent-{agent}` 的方式如 `@agent-coder` 来引用 `coder` subagent。
2. 保持耐心，这不是一个简单的任务，需要考虑每个不同 agent 的配置的规格和要求。

