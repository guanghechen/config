---
name: tmux-pane-collab
description: Use when the user asks the current agent to communicate, discuss, or collaborate with another agent through tmux panes, and provides an explicit target pane ref such as %N, #N, or @M#N. Do not use without a target pane ref; never guess, scan for, or auto-select panes. For a structured code-review loop (findings, per-item resolution, consensus), use multi-agent-review instead.
---

# Tmux Pane Collab

用于通过 tmux pane 与另一个 agent 通信、讨论或协作。

## 使用边界

只有同时满足以下条件才使用本 skill：

- 用户明确要求通过 tmux pane 与其它 agent 进行 multi-agent 协作。
- 用户明确提供目标 pane ref：`%N`、`#N` 或 `@M#N`。

如果用户没有提供目标 pane ref，停止并要求用户补充。不要猜测、扫描或自动选择 pane。

## Pane ref

- `%3` → tmux target `%3`
- `#2` → tmux target `:.2`
- `@1#2` → tmux target `@1.2`

## 基本流程

1. 确认用户是在要求 multi-agent communication / discussion through tmux panes。
2. 校验目标 pane ref，并转换为 tmux target。
3. 若需要对方回发，获取当前 pane id：

   ```bash
   tmux display-message -p '#{pane_id}'
   ```

   如果无法获取，且用户没有提供 reply pane，则要求用户补充。讨论、协商、等待回复等双向场景必须有 `Reply-To`；只有 one-way handoff 可省略。

4. 构造结构化消息并发送到目标 pane。
5. 发送后必须确认消息已经实际提交，而不是只停留在输入框。
6. 如用户要求等待回复，用 `tmux capture-pane -ep -t '<target>'` 读取目标 pane。
7. 多轮协作时保持同一 `Thread`，简洁延续上下文，不粘贴无关 scrollback。

## 消息格式

```text
From: %SOURCE_PANE
To: %TARGET_PANE
Thread: <short-topic>
Turn: <n>
Mode: communicate | discuss | collaborate | handoff | ask | answer
Reply-To: %SOURCE_PANE

Context:
<必要背景；首次消息写任务背景，后续消息写上一轮要点>

Message:
<要发送给 peer agent 的具体内容>

Response contract:
<要求对方如何回复，以及回发到哪个 pane；要求回复保留 From / To / Thread / Turn header>
```

如果只是 one-way handoff，且无法确定当前 pane，可以写 `From: unknown` 并省略 `Reply-To`。如果需要对方回发，必须有有效 `Reply-To`，并要求对方回复时保留相同 `Thread`。

## 发送命令

极短且无特殊字符的消息，可直接键入文本（先不带 Enter，提交统一在下面 verify 步骤完成）：

```bash
tmux send-keys -t '<target>' '<message>'
```

默认优先用 tmux buffer，尤其是多行消息或包含引号、反斜杠、shell 特殊字符的消息：

```bash
tmp=$(mktemp /tmp/tmux-agent-collab.XXXXXX)
cat > "$tmp" <<'MSG'
<structured message>
MSG
tmux load-buffer "$tmp"
tmux paste-buffer -t '<target>'
rm -f "$tmp"
```

不论是上面哪种方式键入/paste，都不要假定已提交。先 capture 看状态，按状态触发（processing 优先判断），最后再 capture 确认：

```bash
tmux capture-pane -ep -t '<target>' | tail -40
```

- pane 正 processing（footer 如 `esc to interrupt`）：**绝不**发 `Escape`（会打断对方 turn）。footer 提示可排队就 `tmux send-keys -t '<target>' Tab`，否则等它空闲。
- 空闲普通 prompt、文本未提交：`tmux send-keys -t '<target>' Enter`。
- 模态编辑器残留 insert 态（vim 类 `-- INSERT --`）：`tmux send-keys -t '<target>' Escape` 后再 `... Enter`。

再次 capture，直到 prompt 清空 / 进入 processing / 出现 queued 提示 / 对方开始回复，才算发送成功。未确认就继续 capture 判断，不要依赖固定 sleep。

## 规则

- 不要猜测、扫描或自动选择 pane。
- 不要把普通单 agent 任务升级为 multi-agent 协作。
- 不要发送 secrets、credentials、`.env*`、`.ssh/` 或敏感日志。
- 默认最多 3 轮；复杂讨论最多 7 轮。退出条件是已达成一致，或所有分歧/不确定问题都已整理为需要用户决策的明确事项。
- 读取 pane 回复时，只提取当前 `Thread` 相关内容；边界不清时说明不确定性。
