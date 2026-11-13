# Statusline 最终设计

> 状态：Final
>
> 实现入口：`rust/ghc-tmux-status`、`script/load-theme.sh`、`script/status-scheduler.sh`

本文是 tmux statusline 的唯一系统级设计说明，定义 renderer、layout、scheduler、
cache、commit 与降级策略。Session 的分组、排序和导航规则见
`session-navigation.md`；性能约束与已接受的优化见 `status-performance.md`。

## 1. 目标与非目标

### 1.1 目标

- 由 Rust 统一持有 `status02` 的状态采集、布局、渲染和提交。
- tmux 继续作为事件源、持久状态所有者和最终绘制器。
- 在多 client、并发 hook、reload 和 worker failure 下最终收敛。
- expensive metric sampling 与每秒 status redraw 解耦。
- 保留可诊断、可回退、可测试的清晰边界。

### 1.2 非目标

- 不引入 daemon。
- 不实现 dynamic plugin loading。
- 不接管 tmux native window list。
- 不让 widget、domain module 或 metric provider 直接读写 tmux。
- 不保留实现过程或历史进度，只记录当前有效 contract。

## 2. 核心决策

| 决策 | 最终选择 | 原因 |
|---|---|---|
| `status02` owner | Rust CLI | 将状态与失败边界集中在可测试代码中 |
| 最终绘制 | tmux format | 保留 native window list 与成熟的 tmux rendering |
| 生命周期 | process-per-event | 当前负载下 daemon 收益不足以覆盖生命周期复杂度 |
| 持久状态 | tmux options | 无额外文件或服务，且可直接观察 |
| layout state | session-scoped | 不同 session 可独立持有 rows、lengths 与 formats |
| metrics | scheduler-owned samples | 避免 widget render 触发外部 IO |
| running / waiting indicator | pane title 与 OSC 9;4 progress state | window live-expand；session lock-owner sampled |
| commit | guarded delta plan | 减少 tmux IPC，并阻止 stale writer |
| fallback | `status01` | Rust 或 scheduler 不可用时保持可用状态栏 |
| theme | generated `@GHC_*` options | renderer 不硬编码 palette |

## 3. 系统边界与所有权

### 3.1 数据流

```text
tmux event / status tick
  -> ghc-tmux-status
  -> guarded snapshot
  -> session group + order
  -> per-session layout
  -> widget render
  -> status composition
  -> delta commit plan
  -> guarded tmux mutation
  -> status refresh
```

数据流只向前推进。Domain 与 render 层返回纯数据；所有外部副作用均收敛到
`TmuxAdapter` 和 scheduler process boundary。

### 3.2 模块职责

| Module | 唯一职责 |
|---|---|
| `cli` | 解析命令；`main` 直接分派到 `runtime` |
| `runtime` | 编排 snapshot、context、render、scheduler 与 commit，不持有 domain 规则 |
| `tmux` | tmux subprocess、framing、guards 与 mutation |
| `layout` | 计算 position、rows、target status、layout key 与 per-session layout reconcile |
| `session` | 分组、排序（含 snapshot 的 ordered group）、focus 与 swap 的纯 domain logic |
| `widget` | 以纯函数产出独立 status fragment 与 width shadow |
| `composer` | 组合 fragments 与 responsive metric guards |
| `status_length` | 计算左右 status length 上限 |
| `commit` | 生成 idempotent tmux command plan |
| `scheduler` | task cadence、claim、lease、completion 与 outcome encoding |
| `metric` | macOS metrics sampling、sample state 编码与 publish policy（freshness、health） |
| `process` | timeout、capture limit、watchdog、process-group reap |
| `introspect` / `observability` | read-only diagnostics 与 opt-in trace |

### 3.3 Single source / single writer

| State | Source of truth | Writer |
|---|---|---|
| selected mode | `@GHC_SL_MODE` | `load-theme.sh` / explicit toggle |
| lifecycle generation | `@GHC_SL_SCHED_ACTIVE/GEN` | `load-theme.sh` |
| scheduler task state | server-scoped task options | guarded Rust scheduler commit |
| rendered session cache | session-scoped `@GHC_SL_*` | guarded Rust commit |
| sampled session states | server-scoped `@GHC_SL_SESSION_STATES` | scheduler lock owner；loader lifecycle reset |
| session virtual order | `@GHC_SL_SESSION_ORDER` | session swap command |
| palette/symbols | generated theme options | external theme generator |
| native window list | tmux | tmux |
| deployed renderer | `bin/ghc-tmux-status` 与 build receipt | `script/build.mjs` |

禁止以下反向依赖：

```text
widget / session / layout -> TmuxAdapter
metric provider          -> TmuxAdapter
composer                 -> cache internals
commit                   -> metric sampling
tmux config              -> Rust internal types
```

## 4. Mode 与 loader 生命周期

### 4.1 Mode contract

| Mode | Position | Renderer |
|---|---|---|
| `01` | top | shell-backed `status01` |
| `11` | bottom | shell-backed `status01` |
| `02` | top | Rust-owned `status02` |
| `12` | bottom | Rust-owned `status02` |

Normalization：

```text
empty   -> 02
03      -> 01
04      -> 02
13      -> 11
14      -> 12
unknown -> 01
```

### 4.2 Reload contract

`script/load-theme.sh` 是 renderer lifecycle 的唯一 writer：

1. 归一化 mode。
2. 将 scheduler 置为 inactive 并 rotate generation。
3. invalidate render revision。
4. 清理所有 session 的 renderer-owned layout/cache overrides；仅当目标不是 `status02`
   时才把 two-row session 的 `status 2` 撤销为 `on`，`status02` reload 保留它，避免
   pane 高度往返变化，由 bootstrap reconcile rows。
5. 加载 `status01`，或使用显式 generation bootstrap `status02`。
6. 注册 lifecycle hooks。
7. 通过 generation CAS 激活 scheduler。

旧 hook、旧 worker 和 superseded loader 因 generation/revision guard 无法重新发布旧状态。

### 4.3 Hook contract

Adaptive mode 注册固定 hooks。Gate 在 server 内以 `if -F` 求值，不满足时不启动 renderer：

- `client-attached[40]`、`client-session-changed[40]`：目标 session 非 `off`，或 rows 为
  `auto` / `1`；
- `client-detached[40]`、`client-resized[40]`：rows 为 `auto` / `1`；
- `session-created[40]`、`session-closed[40]`：session 名不属于 popup / agent；
- `session-renamed[40]`：无 gate，改名可能改变 group membership。

Fixed two-row layout 不写任何依赖 client 宽度的 renderer state；popup / agent 是 `status off`
的分组，不出现在任何 rendered list。Renderer 新增此类读取时（例如 two-row 下按宽度选择
session 窗口），必须同步放宽对应 gate。较早的 tmux 不保证 attach 同时触发
`client-session-changed`，因此保留 `client-attached`。

Hook 仅发送 background reconcile notification。其 stdout、stderr 和非零退出均被隔离，
避免 tmux 进入 view mode；下一次 event 负责重试。Render 不读取 window 状态，因此不注册
`session-window-changed`。

Session policy 是 `tmux.conf` 中的 `session-created[0]`，以纯 tmux 命令在 server 内执行，
早于 renderer hook：popup / agent session 设为 `status off` 与 `detach-on-destroy on`，
`G<digits>-` session 保持 `detach-on-destroy off`，其余 session 以 session 名命名首个 window。

### 4.4 Fallback

以下情况加载 `status01`：

- mode 为 `01` / `11`；
- deployed renderer 不存在或 protocol 不匹配（§4.5），或 scheduler driver 不存在；
- bootstrap apply 失败；
- scheduler activation 失败。

Fresh server 在首个 session 创建前没有 render context。Loader 此时保留 `status01`，并
注册一次性 `session-created[40]` bootstrap hook；首个 session 创建后通过
`load-theme.sh` 重试 lifecycle。其他 fallback 保持稳定，不随新 session 自动重试。

Session-local `status off` 始终由 session policy 持有，loader 与 renderer 均不得把它
误改为 `on`。

### 4.5 Renderer 部署

Scripts 只执行不入库的 `bin/ghc-tmux-status`；`node script/build.mjs` 是它唯一的
writer：

1. `cargo build --release --locked` 后复制到 `target/deploy/`，darwin 上 ad-hoc codesign；
2. staged binary 的 `protocol` 输出必须等于 `script/renderer-protocol`；
3. build 前后 renderer inputs（crate 内除 `target/` 外的文件与 protocol 文件）的
   fingerprint 必须一致；
4. 内容变化（或 `--force`）时以同目录 temp + rename 替换 deployed binary：每次调用都
   看到完整文件，运行中的进程保留旧 inode；
5. 写 `bin/ghc-tmux-status.build.json` receipt，记录 artifact SHA-256、input
   fingerprint、protocol 与 toolchain。

开发构建只写 `target/`，不改变 live renderer；`--output <new-dir>` 在新目录完成同一流程，
不触碰 checkout；`--force` 清空 target 后重新构建，并无条件替换 deployed binary。部署不
reload tmux：新调用立即使用新 binary，已发布的 session cache 等到下一次 lifecycle
event、heartbeat 或 reload 才重新渲染。

`script/renderer-protocol` 是 scripts 与 renderer 之间的 contract 版本，Rust 在编译期
嵌入。Loader 只接受 `protocol` 输出与该文件一致的 renderer，否则按 §4.4 fallback 并
提示运行 build script。CLI 参数、environment transport、ack 或 option ownership 的
不兼容变化必须同时 bump 该值。Protocol 只在 loader 中检查：`git pull` 之后到下一次
reload 之间，新 scripts 仍可能调用旧 renderer。

## 5. Snapshot 与 reconcile

一次 apply 只读取一个 immutable `TmuxSnapshot`，随后为所有目标 session 派生独立的
`SessionLayout` 和 render context。

Snapshot 包含：

- invoking client 的 width、current session、last session 与 host；
- 所有 session 的 id、name、bell、status、layout、length、formats 与 cache witnesses；
- attached clients 的 `(session_id, client_width)`；
- render 所需的 global/server options。

Reconcile 规则：

- effective `status=off` 的 session 跳过；
- detached session 暂不写入，等待 attach/resize event；
- 同一 session 的 rows 使用最窄 attached width；
- 同一 session 的 status lengths 使用最宽 attached width。

这样既保证窄 client 的 row layout 可用，也避免窄 client 把宽 client 的内容上限裁小。

## 6. Layout 与 rows

Adaptive layout 仅适用于 mode `02` / `12`；`status=off` 不产生 layout plan。

`@GHC_SL_ROWS` contract：

```text
unset / empty -> two rows
1             -> one row
2             -> two rows
auto          -> adaptive heuristic
other         -> adaptive heuristic
```

`auto` heuristic：

```text
session group count <= 1 -> one row
client width >= 200      -> one row
otherwise                -> two rows
```

| Layout | Rows | tmux `status` | Key |
|---|---:|---|---|
| wide | 1 | `on` | `{mode}:wide` |
| narrow | 2 | `2` | `{mode}:narrow` |

Wide session 删除 local `status-format` override，回落到 global fallback。Narrow session
持有自己的 `status-format[0]` 与 `status-format[1]`。

## 7. Widget 与 composition

### 7.1 Render contract

```rust
pub struct RenderedSegment {
    pub literal_text: String,
    pub rich_text: String,
}
```

- `literal_text` 是无 style 的可见字符 shadow，用于 steady-layout width calculation；
  dynamic maximum reserve 可由对应 length policy 单独补充。
- `rich_text` 是最终 tmux format fragment。
- Widget 是纯函数：template widget 只组合 cheap native tmux templates，computed widget
  只执行 cheap in-process computation；均不得采样 metrics，也不得执行任意外部 IO。
- 共用 pill 形状的 widget 由同一定义同时生成 `rich_text` 与 `literal_text`。

### 7.2 Widget 分类

| Computed | Template |
|---|---|
| host | prefix indicator |
| session list | fullscreen |
|  | window id |
|  | network |
|  | CPU |
|  | memory |
|  | duration |
|  | date |
|  | time |

Metric widget 读取 sampler-owned tmux options；它们不是 cached metric lifecycle。
Duration 引用 `conf/variable.tmux.conf` 的 `@GHC_SESSION_DURATION_FMT`，由 tmux 在每次
redraw 时按 `%s` 与 `session_created` 计算，因此 session cache 不含时间相关内容。
该公式不得内联进 cache：含 `%` 的 format 展开后超过约 8 KiB 时 tmux 会整段渲染为空，
大 session 组的 right cache 已接近该上限。

### 7.3 Row composition

- `status-left`：host + ordered session list。
- Wide right：prefix + window indicators + responsive metrics。
- Narrow row 0 right：prefix + responsive metrics。
- Narrow row 1：native window list + current-window indicators。

Metric display order：

```text
network -> CPU -> memory -> duration -> date -> time
```

空间不足时的 drop order：

```text
duration -> date -> memory -> CPU -> network
```

time 始终保留；当 time 也放不下时，最终交给 tmux character truncation。

Responsive guard 的 baseline 仍按每个可见 session 一个 state prefix 计算。额外宽度为
active lifecycle 下同时命中 sampled `R` 与 `B` membership 的可见 session 数乘以 2；
session-list renderer 返回同一次选择的可见 slice，overflow 隐藏的 sessions 不参与预算。

- client width 小于 baseline threshold：直接隐藏。
- client width 大于等于 baseline threshold + `2 * visible_session_count`：直接显示。
- 两者之间：展开 sampled membership 计算实际额外预算，再判断是否显示。

条件只返回 boolean，metric body 保持原有 conditional depth，避免改变时间与百分号展开。
这套预算不增加 sampler、timer、tmux options 或 Rust state-triggered reconcile。

## 8. Session list

Session list 的 group、order、focus 与 last-session 语义由 `session-navigation.md` 定义。

渲染约束：

- active style 优先于 last-session style；
- `client_last_session` 仅在当前 group 可见且非 active 时高亮；
- bell source 为各 window 的 `window_bell_flag`，仅在该 window 没有 waiting 或 spinning pane
  时计入（见 §8.1）；
- session item state prefix 可同时包含 running spinner、waiting icon 与 bell，位于 title 前且
  不改变 slant edge；
- `literal_text` 必须包含每个可见 icon 的 width placeholder；
- 超长 session name 在固定 byte budget 内截断；
- tmux 接受 `new-session -s ''`：空 name 显示为 `@GHC_SYM_SESSION_UNNAMED` + session id
  （status01 session pill 同规则），不参与 last-session 高亮；render / navigation context
  以 `session_id` 判定 session 是否解析成功，不依赖 name。

### 8.1 Running / waiting indicator

- Source of truth：live pane 的 `pane_title` 以 Braille spinner
  `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` 之一开头；`pane_dead=1` 始终视为 idle。
  Claude Code hooks 上报 OSC 9;4 progress：`pane_pb_state=indeterminate` 显示固定帧 `⠋`；
  `paused` 表示等待用户输入，显示 `@GHC_SYM_PANE_WAIT`。Waiting 是独立状态，因此
  `indeterminate` 不再让位于 bell。
- 每个 pane 只有一个状态（`waiting > spinning > idle`）。Window item 与 session item 显示其
  panes 状态的去重集合：spinning、waiting 与 bell；bell 只能按 window 归属，仅在所在 window
  没有 waiting 或 spinning pane 时成立。Terminal title 按 `waiting > spinning > bell > idle`
  选择单一状态：

  ```text
  pane_waiting(p)
    = !pane_dead(p) && pane_pb_state(p) = paused

  pane_spinning(p)
    = !pane_dead(p) && pane_title(p) 以 Braille spinner 开头
      || !pane_dead(p) && pane_pb_state(p) = indeterminate

  window_waiting(w)
    = 存在 p ∈ panes(w): pane_waiting(p)

  window_spinning(w)
    = 存在 p ∈ panes(w): pane_spinning(p)

  window_bell(w)
    = window_bell_flag(w) && !window_waiting(w) && !window_spinning(w)

  session_waiting(s)
    = 存在 w ∈ windows(s): window_waiting(w)

  session_spinning(s)
    = 存在 w ∈ windows(s): window_spinning(w)

  session_bell(s)
    = 存在 w ∈ windows(s): window_bell(w)
  ```

  tmux 不提供持久的 pane-level bell；`window_bell_flag` 已表示该 window 下任意 pane 触发的
  bell。因此同一 window 内另一 pane 的 bell 会并入该 window 的 waiting 或 spinning；session
  item 的 bell 与 window list 中显示 bell 的 window 一致。
- `@GHC_WINDOW_PREFIX_FMT` 依次输出 live frame（pane 顺序中首个 spinning pane 的帧，无样式、
  沿用 title style）、waiting icon 与 bell；bell 由 `@GHC_WINDOW_BELL_FMT` 判定。Live frame
  只来自 spinning pane，因此 waiting 需要一次额外的 `P:` traversal（`@GHC_WINDOW_WAITING_FMT`）；
  每个 window 的 pane 很少，接受该开销（见 `status-performance.md` §4.7）。Zoom 是独立
  decorator，显示顺序为 states、zoom、title。
- Pane border 在 title 前显示 hook 上报的 pane state（`@GHC_PANE_BORDER_STATE_FMT`）：
  `paused` 显示 waiting icon，`indeterminate` 显示 `⠋`，字重随 border style。应用自带的
  spinner 已在 `pane_title` 中，不重复绘制。
- Waiting icon 的背景沿用所在 window item、session item 或 pane border 的背景，theme 只设计
  前景色：window prefix 为 `@GHC_SL_FG_WIN{,_ACTIVE,_LAST}_ICON_WAIT`，其中当前 window 用
  pill 文字色以保证对比度；inactive session item 为 `@GHC_SL_FG_SESSION_ITEM_WAIT`，pane
  border 为 `@GHC_PSL_FG_WAIT`。
- Terminal title 使用 session scope：scheduler active 时读取同一份 sampled waiting/running/bell
  membership，否则用 live `W/P` aggregation 保持 status01/fallback 可用；两条路径均按
  `waiting > spinning > bell > idle` 选择，最后显示 `session:window`。Terminal title 不反写
  `pane_title`。
- 每个持锁 scheduler tick 尝试一次发布 `@GHC_SL_SESSION_STATES`：
  `<sample-token><|W$session_id||R$session_id||B$session_id||2$session_id|...>`；`W`/`R`/`B`
  分别表示 waiting/running/bell evidence，彼此独立；有两个或三个状态的 session 另发布
  `|2$session_id|` 或 `|3$session_id|`，供 renderer 的 responsive guard 计算额外宽度。采样
  按真值表组织，每个 session 的三类 traversal 各求值一次；contender 不采样。
  Driver 以版本化 env 请求 renderer
  接管发布；renderer 校验请求后先向 stdout 写出并 flush 固定 ack 行，成功后才进入任何
  发布路径，写失败则放弃整个 tick。接管后，renderer 将发布置于该 tick 首个 mutation queue
  的 guard 之前（metrics completion，否则 heartbeat claim），与该 queue 共享一次 client
  redraw；
  没有 queue 执行的普通出口（not-due、snapshot 读取失败、inactive）单独发布。携带发布的
  queue 无论 skipped、失败或 timeout 都只算已尝试，不重发；ack 后、首个 queue 前崩溃时该
  tick 不发布，由 TTL 兜底。Direct `scheduler-tick` 不发布。
- Driver 不启动 renderer 的出口（snapshot 读取失败、inactive 或非法 generation）由 driver
  单独发布。Renderer 以 status 0/1 结束后，driver 在最终 wait 后读取 ack：只有确认 renderer
  未接管（ack 文件为空，或读到非 ack 的完整行）时才补发一次，采样晚于正常 prelude；完整 ack、
  ack 无法打开或未能读到完整行（unknown），以及 renderer 异常退出（保留 generation fencing）
  时都不补发。发布在执行时采样当前 formats 与 live state，不受 task generation
  guard 约束。
- Session item 检查 lifecycle active 与 exact typed session-id membership；`R`、`W`、`B`
  独立匹配，按 spinner、waiting icon、bell 顺序拼接：无样式的 spinner 在前以沿用 item 颜色，
  带样式的 icon 在后。Inactive item 的 waiting 与 bell prefix 引用共享的
  `@GHC_SESSION_WAIT_PREFIX_FMT` 与 `@GHC_SESSION_BELL_PREFIX_FMT`，不在每个 cached item 中
  重复样式；active item 以自身颜色绘制 plain symbol。Sample 默认由 tmux server 在 12 秒后以
  token prefix CAS 清理；正常 freshness 约为 4–5 秒。发布在 driver delay 之后执行，driver
  首次启动或 reload 后约一个 tick 才出现首个 sample。
- Session item 命中 membership 后，从现有 `status-interval=1` clock 以 `%S mod 2` 派生
  `⠋/⠴`；所有 session 共享 phase，不追踪 pane 的真实 frame。Clock format 缺失或
  malformed 时不显示 marker。
- Session spinner、waiting icon 与 bell 各使用 2 列 title prefix（左侧 gap + marker），三者
  同时存在时共占 6 列；idle 不绘制 padding、保持 baseline layout。Bell 从 index 后移到
  title prefix，glyph count 不变。Session-list `literal_text` 保留单 prefix baseline，避免
  idle/单状态下提前隐藏 metrics；多状态时 responsive guard 读取 count token，`|2$id|` 增加
  2 列、`|3$id|` 增加 4 列。Guard expression 在每个 metric 中重复，而含 time expansion 的
  format 由 tmux 以 8 KiB strftime buffer 展开、超长即整行为空，因此每个 session 的 guard
  不得变长。`status-left-length` 另按每个 group session 增加 4 列静态上界，容纳可能出现的
  另外两个 prefix。接受状态 transition 引起的 session-list reflow；可隐藏的 metrics 优先让出
  空间。
- Window state 在存在 spinning、waiting 或 bell 时各增加 2 列；spinning 与 waiting 可同时
  出现，bell 只在二者都不存在时出现，因此最多 4 列。Idle 不预留、保持 baseline layout；接受
  由此产生的 window-list reflow tradeoff。Bell 与 zoom 从 index 后移到 title prefix，各自的
  glyph count 和 palette 不变。
- Sampled `W/R/B` values、count token 与 frame 不进入 Rust snapshot、render key 或 session
  cache；cache 中仅保存按可见 session IDs 生成的动态表达式；状态变化不触发 renderer
  apply/commit。Bell 改用共享 prefix 后，waiting branch 使每个 item 的 rich text 只增加约
  13 bytes；以短名 fixture 测得的可见 item 数与变更前一致。
- Session item 与 active-scheduler terminal title 是上述 session 定义的 freshness-bounded
  projection：sample 更新前可能暂时保留上一状态，且 consumer 不额外执行 `S/W/P` traversal。
  Scheduler inactive 时 terminal title 改用 live aggregation。Lifecycle fence 清空 sampled
  state；session item 的 waiting、running 与 bell branch 独立 degrade，terminal title 仍按
  单一状态 priority degrade。

## 9. Length 与 cache contract

### 9.1 Status lengths

```text
left floor  = 64
right floor = 84
padding     = 2
left reserve = 4 * session_group_count
left desired = max(left floor, display_width(literal_text) + left reserve + padding)
right desired = max(right floor, display_width(literal_text) + padding)
result      = min(desired, max(client_width, floor))
```

Conditional pill 使用 pessimistic literal shadow。作为最大值，适度 over-reserve 可接受；
underestimate 会造成可见 clipping，因此不可接受。

只有 one-row 的 global `status-format` 按 `status-*-length` 裁剪；two-row session format
不经 length 裁剪，因此 narrow session 不写入 length。

### 9.2 Session-scoped rendered state

```text
@GHC_SL_STATUS02_LEFT
@GHC_SL_STATUS02_RIGHT
@GHC_SL_STATUS02_SESSION_FORMAT
@GHC_SL_STATUS02_CURRENT_FORMAT
@GHC_SL_RENDER_KEY
@GHC_SL_LAYOUT
status-left-length
status-right-length
status
status-format[]
```

四个 rendered cache value 都带固定 witness。只有 cache witnesses、render key、layout、
status 与 row formats 全部匹配时，session 才视为 settled。

- 仅 length drift：wide session 允许走 length-only fast path；narrow session 不写 length。
- 任意其他 drift：提交完整 session reconcile bundle。
- `SessionRenderedStatus` 携带对应 `session_group_count`，commit planner 使用同一 length policy
  计算实际写入的 `status-left-length`。
- Global rendered options：仅作为新 attach session 的稳定 fallback，不拥有 session layout。

## 10. Scheduler 与 metrics

### 10.1 Task contract

| Task | Interval | Execution budget | Lease |
|---|---:|---:|---:|
| metrics | 4 s | 8 s | —（不写 claim） |
| heartbeat | 300 s | 10 s | 20 s |

Driver 约每 4.1 s tick 一次（4 s delay 加启动开销）。Due 按整秒判断，metrics interval
因此与 tick 对齐；更长的 interval 会隔一拍才到期。Metric 新鲜度上限为 10 s，容忍丢失一次
tick。Session cache 不含时间相关内容，heartbeat 只修复 hook 遗漏或失败留下的偏差，最长
修复延迟即其 interval；每次 heartbeat 仍有三批写入（claim、render revision、completion）。

Server state：

```text
generation:sequence:next_due_seconds:lease_until_seconds
```

Status format 通过 `#()` 调用 `script/status-scheduler.sh`。Shell driver 取得 scheduler
single-flight ownership 并负责 process supervision；running-session derived state 按 §8.1
每个持锁 tick 发布一次；Rust 负责 task state transition 和实际 scheduler work。Renderer
stdout 写入本次 invocation 独占创建的 ack 文件（与 lock candidate/update 同目录）；driver
释放 lock 前清理，dead-owner recovery 一并清理遗留文件。

任何 `refresh-client` 都会让 tmux SIGTERM 正在运行的 `#()` job 并启动替代 job。Driver
因此把 TERM 视为重启通知：完成当前周期并等待 renderer 自行结束，替代 job 因 lock 退出。
HUP/INT 仍终止 renderer。

### 10.2 State transition

```text
metrics:   observed -> guarded input read -> sampling -> guarded completion
heartbeat: observed -> exact-state claim + lease -> render -> guarded completion
```

Completion 写入 lease=0。Metrics 不写 claim：每次 option 写入都会让全部 attached client
全量重绘，而 driver lock 已保证 single-flight；input read 不写任何 option，completion 是该
tick 唯一的写入。

必须保持：

- claim 与 completion 都比较 active、generation 与 exact task state（metrics completion
  比较 observed state，heartbeat completion 比较 claimed state）；
- timeout 后的 ambiguous mutation 不在进程内重试；
- metrics 在 completion 前中断不改变任何状态，下一次 tick 直接重跑；heartbeat 的 expired
  lease 由下一次 tick 恢复；
- reload rotate generation 后，旧 worker 不得 publish；
- ordinary application error 保留 scheduler active；
- panic、watchdog、missing binary 或 signal 仅 fence observed generation。

### 10.3 Metrics

macOS provider：

- CPU：native Mach host ticks；
- memory：native memory size + `vm_stat`；
- network：route-selected interface + `netstat` counters，速率按毫秒时间戳计算。

其他 platform 不显示 metric pills。Sampling failure 保留上一份可用 display value，更新
health state，并在下一次 due tick 重试。

## 11. Guarded commit

每次 render 在读取 snapshot 的同一个 tmux queue 中 claim 新 render revision。Commit 同时
检查 revision 与 lifecycle guards，因此 stale writer 无法发布。

Plan 在 32 KiB command budget 内分 chunk：

- Standard / Bootstrap：chunk 失败后，可在相同 guards 下逐命令重试；
- Scheduler：deadline-sensitive ambiguous mutation 不重试，也不发 refresh；committed
  `set` 已重绘 attached clients，refresh 会重启 driver 所在的 status `#()` job；
- final Standard / Bootstrap chunk 可折叠 `refresh-client -S`；
- detached context 跳过 refresh，不影响 mutation success。

## 12. Failure contract

| Failure | Strategy | Observable result |
|---|---|---|
| local `status off` | degrade | 跳过该 session |
| detached session | retry later | attach 后再 reconcile |
| invalid adaptive mode | no-op | 不生成 layout plan |
| snapshot read/parse failure | abort | 保留旧 status |
| widget/composition failure | abort | 保留旧 status |
| metric unsupported/failure | degrade | hidden 或 last-known value |
| session state membership expansion failure | degrade | marker absent；下一位 lock owner 重试 |
| session state producer missing/hung | expire | active fence 立即隐藏，否则 last sample 最多保留 12 s |
| guarded commit skipped | retry later | 新er writer 胜出 |
| tmux commit failure | retry later | guards 允许的旧状态保持可见 |
| renderer/driver unavailable on load | fallback | 使用 `status01` |

Process boundary：

- Rust process watchdog：30 s；
- tmux command timeout：2 s；
- metric command timeout：1 s；
- stdout/stderr capture limit：每 stream 4 MiB；
- timeout 时终止并回收整个 child process group。

## 13. Observability 与 CLI

### 13.1 Trace

```sh
GHC_TMUX_STATUS_TRACE=1 ghc-tmux-status apply manual-apply
```

Trace 仅写 stderr，默认关闭，不改变 status output。

### 13.2 Read-only diagnostics

`ghc-tmux-status dump-state` 报告：

- mode、status、width、current session、group、layout 与 target rows；
- lifecycle generation 与 scheduler health；
- metric freshness、health 与 consecutive errors；
- visible ordered sessions。

`ghc-tmux-status render status02` 输出 rich/literal segments 与左右 length，且不 commit。

### 13.3 CLI surface

```text
ghc-tmux-status apply [event]
ghc-tmux-status apply theme-loaded <generation>
ghc-tmux-status scheduler-tick
ghc-tmux-status render status02
ghc-tmux-status session focus <prev|next|index>
ghc-tmux-status session swap <prev|next>
ghc-tmux-status layout <mode> <status> <width> <session-count> [auto|1|2]
ghc-tmux-status dump-state
ghc-tmux-status protocol
```

`layout` 省略 rows 时使用 two-row default；显式 `auto` 才启用 adaptive heuristic。
`protocol` 输出 script/renderer contract 版本（§4.5）。

## 14. 系统不变量

- `status01` 始终是可用 fallback。
- 无 metrics provider 时 core renderer 仍可运行。
- Native window list owner 始终是 tmux。
- Pure domain/render module 不调用 tmux。
- Widget render 不采样 metrics。
- Session-dependent state 只有 guarded Rust commit 一个 writer。
- Settled state 不产生 tmux mutation。
- Stale generation 与 stale render revision 均不可 publish。
- Bad external data 只能返回 error 或 degrade，不得使 renderer panic。

## 15. 验证

统一入口：

```sh
rust/ghc-tmux-status/check.sh
```

必须覆盖：

- Rust format、unit tests、Clippy 与 release build；
- shell syntax 与 diff hygiene；
- mode/layout/rows/grouping/width contracts；
- client attach/detach/resize/session-change convergence；
- render revision、generation fence、CAS 与 lease recovery；
- driver crash/hang、timeout-after-commit 与 old-generation isolation；
- focus fallback 与 session-scoped render ownership；
- renderer deploy 的 protocol check、atomic replace 与 stale protocol fallback。
