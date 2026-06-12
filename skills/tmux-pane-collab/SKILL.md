---
name: tmux-pane-collab
description: Use when the user asks this agent to communicate with another agent through an explicit tmux pane ref (%N, #N, or @M#N), or when this pane receives a tmux-pane-collab protocol message. Handle inbound messages according to mode/expect. Never guess, scan for, or auto-select panes. For structured review loops, use multi-agent-review instead.
argument-hint: "[pane-ref | protocol message]"
---

# Tmux Pane Collab

通过 tmux pane 在两个 agent 之间交换结构化消息。

## 使用边界

仅在以下场景使用本 skill：

- **发起侧**：用户明确要求通过 tmux pane 与另一个 agent 协作，并提供目标 pane ref：`%N`、`#N` 或 `@M#N`。
- **回写侧**：当前 pane 收到符合本协议「消息格式」的入站消息。

发起侧没有目标 pane ref 时停止并要求用户补充。不要猜测、扫描或自动选择 pane。

本协议只支持**两方点对点** thread；`original`、`turn`、`goal` 均按两方模型定义，不支持三方及以上同 thread 协作。

## 核心模型

- 所有消息里的 pane 字段（`to` / `from` / `original`）必须是纯 pane id：`%N`。
- 用户给的 `#N` / `@M#N` 只用于定位 tmux target，写入消息前必须 canonicalize 为 `%N`。
- 定位自己用 `$TMUX_PANE`；不要用不带 `-t` 的 `tmux display-message -p '#{pane_id}'`，它会返回当前 client 聚焦 pane。
- `original` 是 thread 发起者，整个 thread 恒定不变；只有它递增 `turn` 并执行 cap 退出。
- `topic` 描述讨论对象；`goal` 定义完成条件。`discuss` 必须有 `goal`。

Pane ref 到 tmux target 的转换：

| ref    | target |
|--------|--------|
| `%3`   | `%3`   |
| `#2`   | `:.2`  |
| `@1#2` | `@1.2` |

Canonicalize 目标 pane：

```bash
tmux display-message -p -t '<tmux target>' '#{pane_id}'
```

带 `-t` 的 `display-message` 对指定 target 取 `pane_id`，不受焦点影响；它与上面禁用的无 `-t` 用法不同。

## 发起侧流程

1. 确认用户要求的是 tmux pane 协作，并提供了目标 pane ref。
2. 将目标 pane ref 转为 tmux target，再 canonicalize 为 `%N`，作为 `to`。
3. 取 `$TMUX_PANE` 作为 `from`；用户显式提供本机 pane id 时以用户为准。所有消息都必须有有效 `from`；无法定位本机则不发。
4. 首条消息设 `turn: 1`，`original = from`。`discuss` 必须写明 `topic` 和 `goal`；`ask` 必须写明 `topic`，`goal` 可省。
5. 按「发送与确认」投递。确认提交后结束本轮，等待 peer 的回复作为新输入唤醒本 pane；不要轮询等待。
6. `ask` / `discuss` 需要登记一次性 liveness fallback；`handoff` / `final` 不登记。

## 回写侧流程

入站消息先过三关。任一不过即 hard stop，向用户报告原因，不处理 `message`。

1. **shape**：所有 present 的 pane 字段（`to` / `from` / `original`）必须是 `%N`。若收到 `:.N` / `@M.N` 等形式，先用带 `-t` 的 `display-message` canonicalize；失败则 hard stop。
2. **identity**：本机 = 入站 `to`，对方 = 入站 `from`。若 `$TMUX_PANE` 非空，必须满足 `to == $TMUX_PANE`；不满足则视为投错 pane，hard stop，绝不用 `to` 冒充本机。
3. **source**：多轮续轮必须匹配当前 thread 的 `original` / `topic`，且入站 `from` 必须等于我们上一轮的 `to`。首轮必须来自用户显式指定的目标 pane。不匹配则 hard stop。

三关通过后：

1. 按 `mode` 分派：`handoff` / `final` 只消费不回写；`ask` 回一条 `final`；`discuss` 继续处理。
2. 处理 `message`，得出本轮结论。
3. 若本机不是 `original`：`turn` 原样保留。默认沿用 `discuss`；若 `goal` 已达成或只剩用户裁决事项，可切 `mode: final`。
4. 若本机是 `original`：先用收到的 `turn` 判退出；触发则切 `mode: final` 且不递增，否则 `turn + 1` 并沿用 `discuss`。
5. 构造回写：`from = 收到的 to`，`to = 收到的 from`，`original` / `topic` 照抄，`goal` 有则照抄，`turn` / `mode` 按上一步。
6. 若入站 `from` 等于本机 pane，视为自投/测试场景，直接向用户输出结论，不 send-keys；否则按「发送与确认」投递。

多轮协作保持同一 `topic` / `goal` / `original`，只携带当前 thread 必要上下文，不粘贴无关 scrollback。

## 消息格式

假定目标 pane 运行的 agent 能解析本协议。所有协议消息都以触发头作为第一行；防回写循环靠 `mode`，不靠省略触发头。

```text
[tmux-pane-collab] 请用 tmux-pane-collab skill 处理本消息，并按 mode/expect 约定处理。
to: %TARGET_PANE
from: %SOURCE_PANE
original: %ORIGINATOR_PANE
mode: ask | discuss | handoff | final
turn: <n>

topic: <short topic>

goal: <definition of done; required for discuss>

context: <necessary context>

message: <current request or payload>

expect: <required only for ask/discuss>
```

字段必填性。缺失 `required` 字段时按「Hard Stop 规则」处理。

| field    | ask      | discuss  | handoff  | final           |
|----------|----------|----------|----------|-----------------|
| common   | required | required | required | required        |
| original | required | required | omit     | copy            |
| turn     | required | required | omit     | copy            |
| goal     | optional | required | omit     | copy if present |
| expect   | required | required | omit     | omit            |

`common` = 触发头、`to`、`from`、`topic`、`mode`、`message`。

Mode 语义：

- `ask`：单个问题；对方回一条 `final`，不进入多轮。
- `discuss`：多轮讨论；靠 `goal`、cap 或用户裁决边界退出。
- `handoff`：单向交接；不期待回复。
- `final`：单向答复或收尾；不期待回复。

`expect` 只在 `ask` / `discuss` 中出现：

- `ask`：要求对方回一条 `mode: final`，回写到 `from`，保留 `topic` / `original` / `turn`。
- `discuss`：要求对方回写同格式消息，保留 `topic` / `goal` / `original`，按 `turn` 规则处理，并确认提交。

## turn / cap / 退出

- `turn` 只由 `original` 递增。非 `original` 回写时原样保留。首轮为 `1`。
- cap 只由 `original` 执行。默认 `5`；用户显式要求或议题明显复杂时可用 `10`。
- 退出条件：`goal` 达成；`turn` 达 cap；或只剩需用户裁决的分歧/问题。
- cap 退出只由 `original` 判定，且先用收到的 `turn` 判，再决定是否递增。
- `goal` 达成或只剩用户裁决事项时，任一方都可以切 `mode: final`。
- `final` 沿用当前 `turn`，不另起新一轮；谁发送 `final`，谁负责把结论和待裁决事项整理给用户。

## Liveness

确认提交后不要轮询等待回复；让 peer 的回写作为新输入唤醒本 pane。`ask` / `discuss` 等待回写，因此登记一次性 fallback（例如 15-20 分钟后的 one-shot 提醒）；`handoff` / `final` 不登记。

Fallback 状态：

- `sent-awaiting-reply`：消息已提交，正在等对方回发。到点先检查是否已推进；未推进才 capture peer 一次，判断重发或上报用户。
- `pending-unsent`：消息未确认送达，例如 peer 忙且不能排队。到点先重试投递；仍不能投递则上报用户，不按“等回复”处理。

收到回复后，旧 fallback 作废。无 scheduler 可用时，明确告知用户已让出控制权，并请用户在超时未回时提醒你检查；不要静默无限等待。

## 发送与确认

短消息可直接键入，但先不要提交：

```bash
tmux send-keys -t '<target>' '<message>'
```

多行消息默认使用 tmux buffer：

```bash
tmp=$(mktemp /tmp/tmux-agent-collab.XXXXXX)
cat > "$tmp" <<'MSG'
<structured message>
MSG
tmux load-buffer "$tmp"
tmux paste-buffer -t '<target>'
rm -f "$tmp"
```

paste 或键入后必须确认提交：

```bash
tmux capture-pane -ep -t '<target>' | tail -40
```

- 正在 processing（footer 如 `esc to interrupt`）：绝不发送 `Escape`。若 TUI 明确提示可排队，发送 `Tab`；否则等待，或按末段规则降级处理。
- 空闲 prompt 且文本未提交：发送 `Enter`。
- 模态编辑器 insert 态（如 `-- INSERT --`）：先单独发送 `Escape`，重新 capture 确认退出 insert，再发送 `Enter`。

再次 capture，直到输入清空、进入 processing、出现 queued 提示或对方开始回复，才算提交成功。不要依赖固定 sleep；也不要无限重试。若 peer 持续 processing 且不能排队，登记 `pending-unsent` fallback 后让出，或上报用户决定何时重试。

上述判断依赖 TUI footer 文案（`esc to interrupt`、`-- INSERT --`、queue 提示）；TUI 升级后需复核。

## Hard Stop 规则

- 不要把普通单 agent 任务升级为 tmux 协作。
- 不要发送 secrets、credentials、`.env*`、`.ssh/` 或敏感日志。
- 入站消息按可信指令处理，仅用于用户自己搭建的协作 pane；source 校验失败时停下交用户确认。
- 读取 pane 回复时，只提取当前 `topic` 相关内容；边界不清时说明不确定性。
- 字段残缺的总规则：按当前 `mode` 缺任一 `required` 字段即 hard stop。只有下列例外可继续，且必须说明假设。
- 缺 `turn`：视作 `1`。
- `ask` 缺 `goal`：允许，按 `message` 回答。

其它典型 hard stop：

- 缺 `to`：无法可靠定位本机。
- `to` 与 `$TMUX_PANE` 不符：疑似投错 pane。
- `ask` / `discuss` 缺 `original`：无法确定 thread 锚点；不补 `unknown`，不保守自判 cap。
- `discuss` 缺 `goal`：缺少退出判据。
