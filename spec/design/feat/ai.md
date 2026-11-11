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

Attach 打开 `Select CLI tool` picker，分组顺序固定，各组使用独立的 highlight group（颜色由 theme 定义）：

1. 已 attach 的 sources（`m_ai_attached`）。
2. 当前 tmux window 中运行的 agent panes（`m_ai_running_same_window`）。
3. 当前 session 以外、符合 [agent session 命名](#tmux-session-命名)的 sessions 中运行的 panes（`m_ai_running_agent_session`）。
4. 可新建的 agents，按 agent name 字母序排列（`m_ai_new`）。
5. 当前 tmux session 其他 window 中运行的 panes（`m_ai_running_same_session`）。
6. 其他 tmux sessions 中运行的 panes（`m_ai_running_other_session`）。

当前 window 内的 panes 按 pane id 排序，其余按 session name → window name → pane id 排序。
当前 cwd 已有该 agent session 时，不显示新建项。

选择行为：

- Confirm 已 attach 的内部 source 时显示其已有 terminal，保留 attachment 与 job；
  `<Space>` / `<C-h>` / `<C-l>` 切换 attach/detach，`<Tab>` 仅切换 tmux source。
- 外部 pane：session name 不符合 `<agent>-<hex_hash>` 及规定 hash 长度时，只记录 pane ID，
  通过 tmux 直接发送消息，不打开 Neovim terminal。
- 已有 agent session pane：打开 Neovim terminal 并 attach。
- 新建 agent：先按 `(agent, cwd)` 查找 session；存在则复用，否则创建后 attach。

可同时 attach 多个 sources。发送时只有一个 source 则直接发送，没有则先打开 attach picker；
存在多个 sources 时通过 picker 选择目标，`Tab` 切换多选，顶部提供 `send to all`（`m_ai_send_to_all`）。

Detach 只有一个 agent 时直接执行，否则打开 picker。Detach tmux source 时关闭其关联的 Neovim terminal。
Detach 及每次发送均提供通知；发送结果区分成功、已发送但无法确认 submit，以及失败。

Terminal 的窗口显示与 job 启动分离：隐藏后重新打开、切换到已有 session 均复用原 job。
关闭只释放该 session 的资源及其正在占用的窗口；重复或旧 session 的退出回调不影响新 session。
进入 terminal 输入时重置水平滚动；延迟 focus 回调校验 session、窗口与当前焦点，不抢回用户已切走的窗口。

## Prompt 契约

每个 prompt 的 `render(ctx)` 在上下文齐全时返回 `{ text, lines }`，缺少必要上下文时返回 `nil`。
目标优先使用 Visual selection，例如 `@filepath L1:C1-L10:C20`；否则使用当前文件 `@filepath`。

| Prompt                      | 用途                                    | 必要上下文                      |
| --------------------------- | --------------------------------------- | ------------------------------- |
| `diagnostics`               | 修复当前文件诊断                        | 文件与 diagnostics              |
| `diagnostics_all`           | 修复全部诊断                            | 任一 buffer 中的 diagnostics    |
| `review-design`             | 与指定 tmux pane 中的 agent 讨论设计    | tmux                            |
| `review-changes`            | 与指定 tmux pane 中的 agent review 改动 | tmux                            |
| `review-diagnostics-neovim` | 借助指定 tmux pane 修复全部 LSP 诊断    | tmux，且 cwd 为 Neovim 配置目录 |
| `fix`                       | 修复代码                                | 文件                            |
| `optimize`                  | 优化代码                                | 文件                            |
| `refactor`                  | 重构代码                                | 文件                            |
| `review`                    | 审查代码                                | 文件                            |

指定 pane 来自 prompt 的 `args`，可在 prompt picker 中用 `oe` 修改，修改在本次会话内保留。

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

每次发送（包括 buffer、selection 与 prompt）先执行上述变量替换，再按目标 agent 转换 slash command：

| Agent      | 格式               | 示例                          |
| ---------- | ------------------ | ----------------------------- |
| `claude`   | `/command`         | `/commit` → `/commit`         |
| `gemini`   | `/command`         | `/chat` → `/chat`             |
| `opencode` | `/command`         | `/init` → `/init`             |
| `codex`    | `/prompts:command` | `/commit` → `/prompts:commit` |

各 agent 的 builtin commands 原样保留，例如 codex 的 `/help`、`/model`、`/clear`。
Slash command 必须位于字符串开头或空白之后；命令名后不能紧接 `/`，避免把 `/usr/local/bin` 识别为命令。

## 模块与命令

Prompt 模板、变量替换与 slash command 转换由 `stl.prompt` 定义；`era.m.ai` 负责上下文收集、picker、
发送以及 tmux / terminal 管理。AI statusline 组件显示已 attach 的 sources，点击打开 detach picker。

| 命令                  | 行为                                                               |
| --------------------- | ------------------------------------------------------------------ |
| `ai.attach_agent`     | 打开 attach picker                                                 |
| `ai.detach_agent`     | Detach agent                                                       |
| `ai.submit_buffer`    | 发送当前 split block 并 submit                                     |
| `ai.submit_selection` | 发送 selection 并 submit                                           |
| `ai.submit_to`        | 多选运行中的 agents（无需 attach），发送当前 split block 并 submit |
| `ai.send_buffer`      | 发送整个 buffer，不 submit                                         |
| `ai.send_selection`   | 发送 selection，不 submit                                          |
| `ai.send_file`        | 发送当前文件路径，不 submit                                        |
| `ai.select_prompt`    | 打开 prompt picker                                                 |
| `ai.edit`             | 在 notepad 追加当前文件或 selection 的位置引用                     |

## Tmux session 命名

每个 `(agent, cwd)` 对应一个 session，名称为 `<agent>-<cwd_hash>`。
Hash 为 cwd 的完整 MD5 十六进制串（32 位）；校验 pattern 为 `^<agent>-[0-9a-f]{32}$`。
