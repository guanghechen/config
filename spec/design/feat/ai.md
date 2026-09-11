# AI Widget 设计

本地 AI agent CLI 集成，替代 sidekick.nvim。

## Agent 与 backend

支持以下 agent：

- `claude`：Claude Code。
- `codex`：OpenAI Codex。
- `gemini`：Google Gemini CLI。
- `opencode`：SST OpenCode。

优先使用 tmux；不可用时使用 Neovim 原生 terminal。不支持 zellij。

## Attach 与多 source

Attach 打开 `Select CLI tool` picker，分组顺序固定：

1. 已 attach 的 sources，使用 brightGreen + bold。
2. 正在运行的 agent panes，使用 brightBlue。
3. 可新建的 agents，使用 fg2，按 agent name 字母序排列。

运行中的 panes 优先显示当前 tmux session，再优先当前 window；其余按
session name → window name → pane id 排序。当前 cwd 已有该 agent session 时，不再显示新建项。

选择行为：

- 外部 pane：session name 不符合 `<agent>-<hex_hash>` 及规定 hash 长度时，只记录 pane ID，
  通过 tmux 直接发送消息，不打开 Neovim terminal。
- 已有 agent session pane：打开 Neovim terminal 并 attach。
- 新建 agent：先按 `(agent, cwd)` 查找 session；存在则复用，否则创建后 attach。

可同时 attach 多个 sources。发送时通过 picker 选择目标，`Tab` 切换多选；
存在多个 sources 时，顶部提供 `Send to all`。

Detach 只有一个 agent 时直接执行，否则打开 picker。Detach tmux source 时关闭其关联的 Neovim terminal。
Attach、detach 及每次发送的成功或失败均提供通知。

## Prompt 契约

每个 prompt 的 `render(ctx)` 在上下文齐全时返回 `{ text, header_end }`，缺少必要上下文时返回 `nil`。
目标优先使用 Visual selection，例如 `@filepath :L1:C1-L10:C20`；否则使用当前文件 `@filepath`。
预览中截至 `header_end` 的 header lines 使用 `f_us_ai_prompt_header`。

| Prompt            | 用途             | 必要上下文                   |
| ----------------- | ---------------- | ---------------------------- |
| `diagnostics`     | 修复当前文件诊断 | 文件与 diagnostics           |
| `diagnostics_all` | 修复全部诊断     | 任一 buffer 中的 diagnostics |
| `ask`             | 针对目标提问     | selection 或文件             |
| `explain`         | 解释代码         | selection 或文件             |
| `fix`             | 修复代码         | selection 或文件             |
| `optimize`        | 优化代码         | selection 或文件             |
| `refactor`        | 重构代码         | selection 或文件             |
| `review`          | 审查代码         | selection 或文件             |
| `review_changes`  | 审查 Git 变更    | Git changes                  |
| `test`            | 编写测试         | selection 或文件             |

### 变量替换

变量名匹配 `__[A-Z_]+__`，例如 `__FILE_PATH__`、`__SELECTION_TEXT__`。
赋值必须独占一行，语法为 `<VAR_NAME>=<value>` 或 `<VAR_NAME>="<value with spaces>"`：

```text
__FILE_PATH__=src/main.lua
__SELECTION_TEXT__="function hello() end"
```

通过 `${<VAR_NAME>}` 引用，例如 `${__FILE_PATH__}`。渲染依次执行：

1. 收集全部赋值。
2. 删除赋值行。
3. 将已定义的 `${__VAR__}` 替换为值；未定义的引用原样保留。
4. 去掉结果首尾空白。

### Slash command 转换

发送 prompt 时，按目标 agent 转换 slash command：

| Agent      | 格式               | 示例                          |
| ---------- | ------------------ | ----------------------------- |
| `claude`   | `/command`         | `/commit` → `/commit`         |
| `gemini`   | `/command`         | `/chat` → `/chat`             |
| `opencode` | `/command`         | `/init` → `/init`             |
| `codex`    | `/prompts:command` | `/commit` → `/prompts:commit` |

各 agent 的 builtin commands 原样保留，例如 codex 的 `/help`、`/model`、`/clear`。
Slash command 必须位于字符串开头或空白之后；命令名后不能紧接 `/`，避免把 `/usr/local/bin` 识别为命令。

## 模块与命令

核心模块位于 `lua/era/m/ai/`：`init.lua` 提供入口，`config.lua` 定义 agent 配置，
`prompt.lua` 定义 prompts 与上下文 helper，`types.lua` 定义类型。
AI statusline 组件位于 `lua/era/m/nvimbar/component/`。

| 命令                  | 行为                           |
| --------------------- | ------------------------------ |
| `ai.attach_agent`     | 打开 attach picker             |
| `ai.detach_agent`     | Detach agent                   |
| `ai.submit_buffer`    | 发送当前 split block 并 submit |
| `ai.submit_selection` | 发送 selection 并 submit       |
| `ai.send_buffer`      | 发送整个 buffer，不 submit     |
| `ai.send_selection`   | 发送 selection，不 submit      |
| `ai.send_this`        | 发送当前文件路径               |
| `ai.send_file`        | 发送当前文件内容并 submit      |
| `ai.select_prompt`    | 打开 prompt picker             |
| `ai.edit`             | 使用 AI context 编辑           |

## 高亮

| Highlight group         | 样式与用途                          |
| ----------------------- | ----------------------------------- |
| `f_us_ai_attached`      | brightGreen、bold；已 attach 项     |
| `f_us_ai_new`           | fg2；新建项                         |
| `f_us_ai_prompt_header` | purple、bold；prompt preview header |
| `f_us_ai_running`       | brightBlue；运行中但未 attach       |
| `f_us_ai_send_to_all`   | pink、bold；发送至全部 sources      |

## Tmux session 命名

每个 `(agent, cwd)` 对应一个 session，名称为 `<agent>-<cwd_hash>`。
Hash 取 cwd 的 MD5 十六进制前缀，长度为 `16 - len(agent)`；
校验 pattern 为 `^<agent>-[0-9a-f]{hash_len}$`。
