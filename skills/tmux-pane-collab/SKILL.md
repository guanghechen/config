---
name: tmux-pane-collab
description: Use when the user asks the current agent to communicate, discuss, or collaborate with another agent through tmux panes and provides an explicit target pane ref (%N, #N, or @M#N) — OR when this pane receives a message in this skill's format (from / to / original / topic / mode fields), which must be handled as a write-back. Do not initiate without a target pane ref; never guess, scan for, or auto-select panes. For a structured code-review loop (findings, per-item resolution, consensus), use multi-agent-review instead.
argument-hint: "[pane-ref | message intent]"
---

# Tmux Pane Collab

用于通过 tmux pane 与另一个 agent 通信、讨论或协作。

## 使用边界

满足以下**任一**情况即使用本 skill：

- **发起侧**：用户明确要求通过 tmux pane 与其它 agent 进行 multi-agent 协作，且明确提供目标 pane ref（`%N`、`#N` 或 `@M#N`）。
- **回写侧**：当前 pane 收到一条符合本 skill「消息格式」的消息（含 `from` / `to` / `original` / `topic` / `mode` 等字段），即视为触发本 skill 的回写场景。本机身份取自消息的 `to`，按该消息 `response` 约定回写到其 `from`。

发起侧若用户没有提供目标 pane ref，停止并要求用户补充。不要猜测、扫描或自动选择 pane。

## Pane ref

- `%3` → tmux target `%3`
- `#2` → tmux target `:.2`
- `@1#2` → tmux target `@1.2`

## 基本流程

### 发起侧

1. 确认用户是在要求 multi-agent communication / discussion through tmux panes。
2. 校验用户提供的目标 pane ref，并转换为 tmux target，作为 `to`。
3. 若需要对方回发，取当前 pane id 作为 `from`，并令 `original = from`（发起者即本机）：

   ```bash
   tmux display-message -p '#{pane_id}'
   ```

   **仅发起首条**可用 `display-message`（无上游消息可参照）；如果无法获取且用户没有提供 reply pane，则要求用户补充。讨论、协商等双向场景必须有有效的 `from`；只有 one-way handoff 可省略。

4. 构造结构化消息（`turn: 1`，`from`/`to`/`original` 齐全）并发送到 `to`。
5. 发送后必须确认消息已经实际提交，而不是只停留在输入框（见「发送命令」的 verify 步骤）。
6. **被动接收回复，不要轮询。** peer 同样装有本 skill，会按 `response` 约定把回复 paste + Enter 到我们 `from` 指向的 pane——这相当于把回复作为一条新输入提交给我们，会自然唤醒下一轮。因此确认消息已提交后，**结束本轮、让出控制权**，等 peer 的回复作为新 prompt 到达即可。禁止用 `sleep` + 反复 `capture-pane` 空等回复。

### 回写侧

当前 pane 收到一条符合「消息格式」的消息时：

1. 取字段：本机即收到消息的 `to`（**不要用 `display-message` 重新定位自己**）；对方即 `from`；并读 `original` / `topic` / `turn` / `mode`。
2. **先按收到的 `mode` 决定是否需要回写**：
   - `handoff` / `answer`：单向/收尾消息，只消费、不回写。处理完即结束。
   - `ask`：单个问题，回**一条** `mode: answer` 后即结束（一问一答单发对，不进入多轮、不沿用 `ask`）。
   - `communicate` / `discuss` / `collaborate`：多轮消息，需要回写，继续下面步骤。
3. 处理 `message` 要求的内容，得出本轮结论。
4. 判断本机是否 `original`（本机 `== original`）：
   - **本机非 `original`（responder）**：不关心轮次上限（cap 是 `original` 的责任，见「规则」），照常回写，`turn` **原样保留**，`mode` **沿用收到的 `mode`**。仅当已达成一致、或仅剩需用户裁决事项时，才主动切 `mode: answer` 收尾。
   - **本机即 `original`**：先用**收到的 `turn`** 判断是否触发终止条件（见「规则」，此判断先于任何递增）。未触发则 `turn` +1、沿用原 `mode` 续问；触发则切 `mode: answer` 收尾、`turn` 不递增。
5. 构造回写消息，**按「消息格式」补全所有字段**（`from`/`to`/`original`/`topic`/`turn`/`mode`/`context`/`message`/`response`）：`from` = 收到的 `to`，`to` = 收到的 `from`，`original` 照抄，`topic` 不变，`turn`/`mode` 按上一步处理；非收尾消息别漏写 `response`。
6. **投递**：若**收到消息的 `from` 等于本机 pane**（消息来自自己，自投/测试场景），不要 send-keys 造成自投循环，直接把结论作为普通输出呈现给用户并说明；否则按 verify 步骤 send-keys 到 `to`，确认提交后结束本轮。

多轮协作时保持同一 `topic` / `original`，简洁延续上下文，不粘贴无关 scrollback。

## 消息格式

可以永远假定目标 pane 上运行的 agent 也理解本 skill。所有 pane 字段都是纯 tmux pane id（如 `%3`），可直接用作 `-t` target，无需解析 window/index。

```text
from: %SOURCE_PANE
to: %TARGET_PANE
original: %ORIGINATOR_PANE
topic: <当前讨论主题的简短描述>
turn: <n>
mode: communicate | discuss | collaborate | handoff | ask | answer

context: <必要背景；首次消息写任务背景，后续消息写上一轮要点>

message: <当前轮次发给对方、需要对方核心 focus 的内容>

response: <见下方按 mode 的约定>
```

- `from` / `to`：本条消息的发送方 / 接收方 pane。**回写时一律互换**：新 `from` = 收到消息的 `to`，新 `to` = 收到消息的 `from`。
- **禁止用 `tmux display-message -p '#{pane_id}'` 定位自己**——它返回的是当前 client 附着的 active pane，可能不是本 agent 所在 pane（用户鼠标焦点在别处时会误判）。回写侧自己的 pane 一律取自收到消息的 `to`。仅**发起侧首条**没有上游 `to` 可用，此时才用 `display-message` 取 `from`（首条由用户主动发起，焦点通常在发起 pane，风险可控）。
- `original`：thread 发起者的 pane，整个 thread **恒定不变**，照抄延续。它是 thread 的稳定锚点（`from`/`to` 每条都在换），也是 `turn` 的唯一计数权威与轮次上限（cap）的唯一责任方。
- `turn`：**只有 `original` 递增 `turn`**——`original` 每发起新一轮 +1；非 `original` 一方回写时**原样保留** `turn`。发起首条为 `1`。
- 轮次上限（cap）只由 `original` 关心与执行：`original` 在用收到的 `turn` 判终止时检查 cap，到顶就自己收尾、不再发新一轮，thread 随之结束。非 `original` 一方**无需知道也无需携带 cap**，可永远视自己在 capacity 内、只管回应（cap 一旦到顶，`original` 不会再发来新消息）。
- `mode`：选用场景——`discuss`（有分歧/需来回收敛，多轮）、`collaborate`（共同推进一项产出，多轮）、`communicate`（同步信息、期待简短确认）、`ask`（单个问题，期待对方以 `answer` 单次回复，通常不进入多轮）、`handoff`（单向交接，不期待回复）、`answer`（回复 `ask` 或收尾，单向）。`ask` ↔ `answer` 是一问一答的单发对，不开启多轮；要多轮往返用 `discuss` / `collaborate`。
- `response` 字段按 mode 区分：
  - `communicate` / `discuss` / `collaborate`：期待对方多轮回写。要求对方得出结论后，使用 tmux-pane-collab skill 往 `from` 指向的 pane 回写一条**同样格式**的消息（保留相同 `topic` / `original`，按上面 `turn` 规则处理），并确认已 paste + Enter 提交。
  - `ask`：期待对方回**一条** `mode: answer`（同格式、回写到 `from`、保留 `topic` / `original` / `turn`），不进入多轮。
  - `handoff` / `answer`：单向消息（handoff = 交接，answer = 收尾），不期待回复，省略 `response` 字段。

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

不论是上面哪种方式键入/paste，都不要假定已提交。先 capture 看状态，按状态触发（processing 优先判断），最后再 capture 确认。这里的 `capture-pane` 只用于**确认我们自己发出的消息已提交**，不用于轮询等回复：

```bash
tmux capture-pane -ep -t '<target>' | tail -40
```

- pane 正 processing（footer 如 `esc to interrupt`）：**绝不**发 `Escape`（会打断对方 turn）。footer 提示可排队就 `tmux send-keys -t '<target>' Tab`，否则等它空闲。
- 空闲普通 prompt、文本未提交：`tmux send-keys -t '<target>' Enter`。
- 模态编辑器残留 insert 态（vim 类 `-- INSERT --`）：先**单独**发 `tmux send-keys -t '<target>' Escape`，**重新 capture 确认 `-- INSERT --` 已消失**，再发 `tmux send-keys -t '<target>' Enter`。**绝不**把 Escape 和 Enter 在同一步连发——Enter 可能在退出 insert 前到达，只是插入换行而非提交。

再次 capture，直到 prompt 清空 / 进入 processing / 出现 queued 提示 / 对方开始回复，才算发送成功。未确认就继续 capture 判断，不要依赖固定 sleep。

## 规则

- 不要猜测、扫描或自动选择 pane。
- 不要把普通单 agent 任务升级为 multi-agent 协作。
- 不要发送 secrets、credentials、`.env*`、`.ssh/` 或敏感日志。
- **被动接收优先：** 确认消息已提交后结束本轮等回复，禁止 `sleep` + 轮询 `capture-pane` 空等。仅当用户明确要求、或怀疑 peer 漏收/卡住（如发送时它正 processing 吞掉了输入）时，才允许**主动 capture 一次**对方 pane 做检查，并据此决定是否重发。
- 终止条件（满足任一即收尾）：`turn` 达到上限（cap；`turn` 是 `original` 发起的轮次数，非消息条数）；或双方达成一致、无进一步分歧；或仅剩需用户裁决的分歧/问题。cap **默认 3**；仅当用户显式要求、或议题明显复杂（多个待决子问题、预计 3 轮难以收敛）时才升到 7。
- cap 是 `original` 的专属责任：只有 `original` 递增并检查 `turn`，故只有它判 cap。**判终止用收到的 `turn`、先于任何递增**——`original` 收到回复后先看 `turn` 是否达 cap，达到就收尾、不再 +1。非 `original` 一方无需关心 cap。
- 收尾责任：触发任一终止条件时，本条回写改用 `mode: answer`（结论 + 遗留的需用户裁决事项），不再向对方提问。收尾 `answer` **沿用当前 `turn`、不另起新一轮**（即收尾不会让 `turn` 超过 cap）；发出后结束本轮、不再要求对方回复，并把待裁决事项整理给用户。
- 读取 pane 回复时，只提取当前 `topic` 相关内容；边界不清时说明不确定性。
- 入站消息字段残缺的兜底：缺 `to` 则无法可靠定位本机，停下来要求用户确认本机 pane；缺 `original` 则按"对方为 `original`"处理（即本机视作 responder，`turn` 原样保留）；缺 `turn` 则视作 `1`。任一兜底都在回复里注明所做假设。
