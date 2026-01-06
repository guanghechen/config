为 codex / gemini / opencode 也应用上我们的优化，具体地：

1. codex: 同步更新到 ~/.config/codex/ 下
   - CLAUDE.md 同步到 ~/.config/codex/AGENTS.md 下。 
   - commands/ 同步到 ~/.config/codex/prompts/ 下
   - agents/   同步到 ~/.config/codex/agents/ 下
   - codex 不支持 subagents，如果 slash commands 中含有引用 subagent 的描述，轻微修改它，让它“参见 ~/.config/codex/agents/{agent}.md”中的 spec

2. gemini: 同步更新到 ~/.gemini/ 下
   - CLAUDE.md 同步到 ~/.gemini/GEMINI.md 下。 
   - commands/ 同步到 ~/.gemini/commands/ 下
   - agents/   同步到 ~/.gemini/agents/ 下
   - gemini 不支持 subagents，如果 slash commands 中含有引用 subagent 的描述，轻微修改它，让它“参见 ~/.gemini/agents/{agent}.md”中的 spec

3. opencode: 同步更新到 ~/.config/opencode/ 下
   - CLAUDE.md 同步到 ~/.config/opencode/AGENTS.md 下。 
   - commands/ 同步到 ~/.config/opencode/commands/ 下
   - agents/   同步到 ~/.config/opencode/agents/ 下

----

等所有的同步完成后，依次进入 codex / gemini / opencode 的配置目录进行提交，提交遵循我们的 /commit (commands/commit.md) 的规范

