---
name: tmux-pane-collab
description: Use when the user asks the current agent to communicate, discuss, or collaborate with another agent through tmux panes, and provides an explicit target pane ref such as %N, #N, or @M#N. Do not use without a target pane ref; never guess, scan for, or auto-select panes. For a structured code-review loop (findings, per-item resolution, consensus), use multi-agent-review instead.
argument-hint: "[pane-ref | message intent]"
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
5. 如用户要求等待回复，用 `tmux capture-pane -ep -t '<target>'` 读取目标 pane。
6. 多轮协作时保持同一 `Thread`，简洁延续上下文，不粘贴无关 scrollback。

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

极短且无特殊字符的消息可用：

```bash
tmux send-keys -t '<target>' '<message>' Enter
sleep 2 && tmux send-keys -t '<target>' C-m C-m
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
sleep 2 && tmux send-keys -t '<target>' C-m C-m
```

## 规则

- 不要猜测、扫描或自动选择 pane。
- 不要把普通单 agent 任务升级为 multi-agent 协作。
- 不要发送 secrets、credentials、`.env*`、`.ssh/` 或敏感日志。
- 默认最多 3 轮；复杂讨论最多 7 轮。退出条件是已达成一致，或所有分歧/不确定问题都已整理为需要用户决策的明确事项。
- 读取 pane 回复时，只提取当前 `Thread` 相关内容；边界不清时说明不确定性。
