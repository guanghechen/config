---
name: tmux-cowork
description: >-
  Use when the user asks this agent to send a structured agent-to-agent
  message through an explicit tmux pane ref (%N, #N, or @M#N), or when this
  pane receives a tmux-cowork protocol message. Modes: one-shot ask,
  multi-round discuss, one-way handoff/final, structured adversarial code
  review. For raw pane operations use tmux instead; never guess, scan for,
  or auto-select panes.
argument-hint: "[pane-ref | protocol message]"
---

# Tmux Cowork

通过 tmux pane 在两个 agent 之间交换结构化消息。

## 使用边界

仅在以下场景使用本 skill：

- **发起侧**：用户明确要求通过 tmux pane 向另一个 agent 发送结构化协作消息，并提供目标 pane ref：`%N`、`#N` 或 `@M#N`。
- **回写侧**：当前 pane 收到符合本协议「消息格式」的入站消息。

发起侧没有目标 pane ref 时停止并要求用户补充。不要猜测、扫描或自动选择 pane。

本协议只支持**两方点对点** thread；`original`、`turn`、`goal` 均按两方模型定义，不支持三方及以上同 thread 协作。

## 核心模型

- 所有消息里的 pane 字段（`to` / `from` / `original`）必须是纯 pane id：`%N`。
- 用户给的 `#N` / `@M#N` 只用于定位 tmux target，写入消息前必须 canonicalize 为 `%N`。
- 定位自己用 `$TMUX_PANE`；不要用不带 `-t` 的 `tmux display-message -p '#{pane_id}'`，它会返回当前 client 聚焦 pane。
- `original` 是 thread 发起者，整个 thread 恒定不变；只有它递增 `turn` 并裁定退出 / 收尾。
- `topic` 描述讨论对象；`goal` 定义完成条件。`discuss` / `review` 必须有 `goal`。

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
4. 首条消息设 `turn: 1`，`original = from`。`discuss` / `review` 必须写明 `topic` 和 `goal`；`ask` 必须写明 `topic`，`goal` 可省。
5. 按「发送与确认」投递。确认提交后结束本轮，等待 peer 的回复作为新输入唤醒本 pane；不要轮询等待。
6. `ask` / `discuss` / `review` 需要登记一次性 liveness fallback；`handoff` / `final` 不登记。

## 回写侧流程

入站消息先过三关。任一不过即 hard stop，向用户报告原因，不处理其 body。

1. **shape**：所有 present 的 pane 字段（`to` / `from` / `original`）必须是 `%N`。若收到 `:.N` / `@M.N` 等形式，先用带 `-t` 的 `display-message` canonicalize；失败则 hard stop。
2. **identity**：本机 = 入站 `to`，对方 = 入站 `from`。若 `$TMUX_PANE` 非空，必须满足 `to == $TMUX_PANE`；不满足则视为投错 pane，hard stop，绝不用 `to` 冒充本机。
3. **source**：多轮续轮必须匹配当前 thread 的 `original` / `topic`，且入站 `from` 必须等于我们上一轮的 `to`。首轮必须来自用户显式指定的目标 pane。不匹配则 hard stop。

三关通过后：

1. 按 `mode` 分派：`handoff` / `final` 只消费不回写；`ask` 回一条 `final`；`discuss` / `review` 进入多轮（轮次 / 退出见「多轮契约」；`review` 的 packet / findings / resolution 见 references/review.md）。
2. 处理 body，得出本轮结论。
3. 若本机不是 `original`（discuss / review 续轮）：`turn` 原样保留，始终沿用当前 mode，不切 `final`；认为可收敛时把结论与理由写入 body，交 `original` 裁定收尾。
4. 若本机是 `original`：按「多轮契约」的退出规则，决定 `turn + 1` 续轮还是切 `mode: final`（切 `final` 不递增）。
5. 构造回写：`from = 收到的 to`，`to = 收到的 from`，`original` / `topic` 照抄，`goal` 有则照抄，`turn` / `mode` 按上一步。
6. 若入站 `from` 等于本机 pane，视为自投/测试场景，直接向用户输出结论，不 send-keys；否则按「发送与确认」投递。

## 消息格式

假定目标 pane 运行的 agent 能解析本协议。所有协议消息都以触发头作为第一行；防回写循环靠 `mode`，不靠省略触发头。

```text
[tmux-cowork] 请用 tmux-cowork skill 处理本消息，并按 mode/expect 约定处理。
to: %TARGET_PANE
from: %SOURCE_PANE
original: %ORIGINATOR_PANE
mode: ask | discuss | review | handoff | final
turn: <n>

topic: <short topic>
goal: <definition of done; required for discuss/review>
expect: <required only for ask/discuss/review>

context: <necessary context>

--------

<request / packet / findings / reply>
```

body 为消息末段：第一处独占一行的 `--------`（恰 8 个 `-`，上下各空一行）之后、到消息末尾的全部内容即 body，opaque，不再解析为协议字段。约束：envelope 字段值内不得独占一行出现该 8-dash 串；body 内部出现无妨（已在分隔点之后）。

字段必填性。缺失 `required` 字段时按「Hard Stop 规则」处理。

| field    | ask      | discuss  | review   | handoff  | final           |
|----------|----------|----------|----------|----------|-----------------|
| common   | required | required | required | required | required        |
| original | required | required | required | omit     | copy            |
| turn     | required | required | required | omit     | copy            |
| goal     | optional | required | required | omit     | copy if present |
| expect   | required | required | required | omit     | omit            |

`common` = 触发头、`to`、`from`、`topic`、`mode`、body（`--------` 之后的段）。

Mode 语义：

- `ask`：单个问题；对方回一条 `final`，不进入多轮。
- `discuss`：多轮讨论；靠 `goal`、收敛一致或无新思路交用户退出。
- `review`：对抗式 code review；`discuss` flow + 结构化 body template，期望快速收敛（典型 2 轮）。
- `handoff`：单向交接；不期待回复。
- `final`：单向答复或收尾；不期待回复。

处理位置：除 `review` 的结构化 body 在 references/review.md 外，其余均在本文件。

`expect` 只在 `ask` / `discuss` / `review` 中出现，声明期待的回写：`ask` 期待对方回一条 `mode: final`；`discuss` / `review` 期待同格式续轮消息（字段构造见「回写侧流程」）。

## 多轮契约（discuss / review）

`discuss` / `review` 多轮往返，由 `original` 记账，靠 `goal` / 收敛一致 / 无新思路交用户退出，`turn` 达 `10` 兜底。`review` 是 `discuss` 的特化（结构化 body + 对抗 guardrail，见 references/review.md）。

- **turn**：只由 `original` 递增，非 `original` 回写时原样保留，首轮为 `1`；`final` 沿用当前 `turn`，不另起一轮。
- **退出**：满足其一即可——`goal` 达成 / 双方收敛一致 / 无新思路交用户 / `turn` 达硬上限 `10`；「无新思路」须给已试方向与交用户理由，不当逃生舱。**退出与收尾只由 `original` 裁定**：先用收到的 `turn` 判上限再决定是否递增；非 `original` 不切 `final`，只在回写 body 表达收敛意见交 `original` 裁定。收尾时 `original` 把结论与待裁决事项整理交用户。
- **收敛纪律**：保持同一 `topic` / `goal` / `original`，每轮只收窄、不重开已定事项；只携带当前 thread 必要上下文，不粘贴无关 scrollback。

## Liveness

确认提交后不要轮询等待回复；让 peer 的回写作为新输入唤醒本 pane。`ask` / `discuss` / `review` 等待回写，因此登记一次性 fallback（例如 15-20 分钟后的 one-shot 提醒）；`handoff` / `final` 不登记。

Fallback 状态：

- `sent-awaiting-reply`：消息已提交，正在等对方回发。到点先检查是否已推进；未推进才 capture peer 一次，判断重发或上报用户。
- `pending-unsent`：消息未确认送达，例如 peer 忙且不能排队。到点先重试投递；仍不能投递则上报用户，不按“等回复”处理。

收到回复后，旧 fallback 作废。无 scheduler 可用时，明确告知用户已让出控制权，并请用户在超时未回时提醒你检查；不要静默无限等待。

## 发送与确认

短消息可直接键入，但先不要提交：

```bash
tmux send-keys -t '<target>' '<structured message>'
```

多行消息默认使用 tmux buffer：

```bash
tmp=$(mktemp /tmp/tmux-cowork.XXXXXX)
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
- `ask` 缺 `goal`：允许，按 body 回答。

其它典型 hard stop：

- 缺 `to`：无法可靠定位本机。
- `to` 与 `$TMUX_PANE` 不符：疑似投错 pane。
- `ask` / `discuss` / `review` 缺 `original`：无法确定 thread 锚点；不补 `unknown`，不自行裁定退出 / 收尾。
- `discuss` / `review` 缺 `goal`：缺少退出判据。
