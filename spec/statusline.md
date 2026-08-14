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
| running indicator | tmux title-derived state | window live-expand；session lock-owner sampled |
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
| `cli` / `app` | 解析命令并暴露 application operations |
| `runtime` | 编排 snapshot、context、render、scheduler 与 commit |
| `tmux` | tmux subprocess、framing、guards 与 mutation |
| `layout` | 计算 position、rows、target status 与 layout key |
| `session` | 分组、排序、focus 与 swap 的纯 domain logic |
| `status_widget` | 约束 template/computed widget 的统一接口 |
| `widget` | 产出独立 status fragment 与 width shadow |
| `composer` | 组合 fragments 与 responsive metric guards |
| `status_length` | 计算左右 status length 上限 |
| `commit` | 生成 idempotent tmux command plan |
| `scheduler` | task cadence、claim、lease 与 completion |
| `metric` / `platform` | platform detection 与 metrics sampling |
| `process` | timeout、capture limit、watchdog、process-group reap |
| `introspect` / `observability` | read-only diagnostics 与 opt-in trace |

### 3.3 Single source / single writer

| State | Source of truth | Writer |
|---|---|---|
| selected mode | `@GHC_SL_MODE` | `load-theme.sh` / explicit toggle |
| lifecycle generation | `@GHC_SL_SCHED_ACTIVE/GEN` | `load-theme.sh` |
| scheduler task state | server-scoped task options | guarded Rust scheduler commit |
| rendered session cache | session-scoped `@GHC_SL_*` | guarded Rust commit |
| running sessions | server-scoped `@GHC_SL_RUNNING_SESSIONS` | scheduler lock owner；loader lifecycle reset |
| session virtual order | `@GHC_SL_SESSION_ORDER` | session swap command |
| palette/symbols | generated theme options | external theme generator |
| native window list | tmux | tmux |

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
4. 清理所有 session 的 renderer-owned layout/cache overrides。
5. 加载 `status01`，或使用显式 generation bootstrap `status02`。
6. 注册 lifecycle hooks。
7. 通过 generation CAS 激活 scheduler。

旧 hook、旧 worker 和 superseded loader 因 generation/revision guard 无法重新发布旧状态。

### 4.3 Hook contract

Adaptive mode 注册固定 hooks：

```text
client-attached[40]
client-detached[40]
client-resized[40]
client-session-changed[40]
session-created[40]
session-closed[40]
session-renamed[40]
session-window-changed[40]
```

Hook 仅发送 background reconcile notification。其 stdout、stderr 和非零退出均被隔离，
避免 tmux 进入 view mode；下一次 event 负责重试。

### 4.4 Fallback

以下情况加载 `status01`：

- mode 为 `01` / `11`；
- Rust binary 或 scheduler driver 不存在；
- bootstrap apply 失败；
- scheduler activation 失败。

Fresh server 在首个 session 创建前没有 render context。Loader 此时保留 `status01`，并
注册一次性 `session-created[40]` bootstrap hook；首个 session 创建后通过
`load-theme.sh` 重试 lifecycle。其他 fallback 保持稳定，不随新 session 自动重试。

Session-local `status off` 始终由 session policy 持有，loader 与 renderer 均不得把它
误改为 `on`。

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

- `literal_text` 是无 style 的可见字符 shadow，仅用于 width calculation。
- `rich_text` 是最终 tmux format fragment。
- `TemplateWidget` 只组合 cheap native tmux templates。
- `ComputedWidget` 只执行 cheap in-process computation。
- Widget render 不得采样 metrics，也不得执行任意外部 IO。

### 7.2 Widget 分类

| Computed | Template |
|---|---|
| host | prefix indicator |
| session list | fullscreen |
| duration | window id |
|  | network |
|  | CPU |
|  | memory |
|  | date |
|  | time |

Metric widget 读取 sampler-owned tmux options；它们不是 cached metric lifecycle。

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

## 8. Session list

Session list 的 group、order、focus 与 last-session 语义由 `session-navigation.md` 定义。

渲染约束：

- active style 优先于 last-session style；
- `client_last_session` 仅在当前 group 可见且非 active 时高亮；
- bell source 为 tmux `session_alerts`，包含 `!` 即表示该 session 有 bell；
- session item state prefix 为互斥的 running spinner 或 bell，位于 title 前且不改变 slant edge；
- `literal_text` 必须包含每个可见 icon 的 width placeholder；
- 超长 session name 在固定 byte budget 内截断。

### 8.1 Running indicator

- Source of truth：live pane 的 `pane_title` 以 Braille spinner
  `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` 之一开头；`pane_dead=1` 始终视为 idle。
- 状态按以下定义逐级聚合，且每一级均满足 `spinning > bell > idle`：

  ```text
  pane_spinning(p)
    = !pane_dead(p) && pane_title(p) 以 Braille spinner 开头

  window_spinning(w)
    = 存在 p ∈ panes(w): pane_spinning(p)

  window_bell(w)
    = window_bell_flag(w) && !window_spinning(w)

  session_spinning(s)
    = 存在 w ∈ windows(s): window_spinning(w)

  session_bell(s)
    = session_alerts(s) 包含 "!" && !session_spinning(s)
  ```

  tmux 不提供持久的 pane-level bell；`window_bell_flag` 已表示该 window 下任意 pane 触发的
  bell。
- `@GHC_WINDOW_PREFIX_FMT` 用 native `P:` 动态聚合 live frame，并在同一个两列 state slot
  中以 bell 作为 fallback；因此 spinner 与 bell 不会同时显示，也不需要第二次 pane traversal。
  Zoom 是独立 decorator，显示顺序为 state、zoom、title。
- Terminal title 使用 session scope：sampled running membership 命中时显示 spinner，否则从
  `session_alerts` 派生 bell，最后显示 `session:window`。Terminal title 不反写 `pane_title`。
- Scheduler lock owner 用一条 command queue 发布
  `@GHC_SL_RUNNING_SESSIONS = <sample-token><|$session_id|...>`；contender 不采样。
- Session item 检查 lifecycle active 与 exact session-id membership。Sample 默认由 tmux
  server 在 12 秒后以 token prefix CAS 清理；正常 freshness 约为 4–5 秒。
- Session item 命中 membership 后，从现有 `status-interval=1` clock 以 `%S mod 4` 派生
  `⠋/⠹/⠴/⠧`；所有 session 共享 phase，不追踪 pane 的真实 frame。Clock format 缺失或
  malformed 时不显示 marker。
- Session spinner 仅在 running 时作为 title prefix 增加 2 列（左侧 gap + frame）；idle 不绘制
  padding、保持 baseline layout。Bell 从 index 后移到 title prefix，glyph count 不变；bell
  只占用 spinner 的 fallback branch。`literal_text` shadow 按两种状态的最大宽度预算，接受
  running transition 引起的
  session-list reflow。
- Window live frame 仅在 running 时增加 2 列，idle 不预留 frame、保持 baseline layout；
  接受由此产生的 window-list reflow tradeoff。Bell 与 zoom 从 index 后移到 title prefix，
  各自的 glyph count 和 palette 不变。
- 该状态不进入 Rust snapshot、render key 或 session cache；spinner frame 变化不触发 renderer
  apply/commit。
- Session item 与 terminal title 是上述 session 定义的 freshness-bounded projection：sample
  更新前可能暂时保留上一状态；不额外执行 `S/W/P` traversal。Lifecycle fence 清空 sampled
  state；format expansion failure 保持空 marker，并继续抑制低优先级 bell。

## 9. Length 与 cache contract

### 9.1 Status lengths

```text
left floor  = 64
right floor = 84
padding     = 2
desired     = max(floor, display_width(literal_text) + padding)
result      = min(desired, max(client_width, floor))
```

Conditional pill 使用 pessimistic literal shadow。作为最大值，适度 over-reserve 可接受；
underestimate 会造成可见 clipping，因此不可接受。

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

- 仅 length drift：允许走 length-only fast path。
- 任意其他 drift：提交完整 session reconcile bundle。
- Global rendered options：仅作为新 attach session 的稳定 fallback，不拥有 session layout。

## 10. Scheduler 与 metrics

### 10.1 Task contract

| Task | Interval | Execution budget | Lease |
|---|---:|---:|---:|
| metrics | 5 s | 8 s | 15 s |
| heartbeat | 30 s | 10 s | 20 s |

Server state：

```text
generation:sequence:next_due_seconds:lease_until_seconds
```

Status format 通过 `#()` 调用 `script/status-scheduler.sh`。Shell driver 先取得 scheduler
single-flight ownership，再 materialize running-session derived state，并负责 process
supervision；Rust 负责 task state transition 和实际 scheduler work。

### 10.2 State transition

```text
observed
  -> exact-state claim + lease
  -> task execution
  -> guarded publish
  -> completion with lease=0
```

必须保持：

- claim 比较 active、generation 与 exact observed task state；
- timeout 后的 ambiguous mutation 不在进程内重试；
- expired lease 由下一次 tick 恢复；
- reload rotate generation 后，旧 worker 不得 publish；
- ordinary application error 保留 scheduler active；
- panic、watchdog、missing binary 或 signal 仅 fence observed generation。

### 10.3 Metrics

macOS provider：

- CPU：native Mach host ticks；
- memory：native memory size + `vm_stat`；
- network：route-selected interface + `netstat` counters。

其他 platform 不显示 metric pills。Sampling failure 保留上一份可用 display value，更新
health state，并在下一次 due tick 重试。

## 11. Guarded commit

每次 render 在读取 snapshot 的同一个 tmux queue 中 claim 新 render revision。Commit 同时
检查 revision 与 lifecycle guards，因此 stale writer 无法发布。

Plan 在 32 KiB command budget 内分 chunk：

- Standard / Bootstrap：chunk 失败后，可在相同 guards 下逐命令重试；
- Scheduler：deadline-sensitive ambiguous mutation 不重试；
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
| running membership expansion failure | degrade | marker absent；下一位 lock owner 重试 |
| running producer missing/hung | expire | active fence 立即隐藏，否则 last sample 最多保留 12 s |
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
- widget lifecycle placement count；
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
```

`layout` 省略 rows 时使用 two-row default；显式 `auto` 才启用 adaptive heuristic。

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
- focus fallback 与 session-scoped render ownership。
