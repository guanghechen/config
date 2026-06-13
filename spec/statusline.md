# Statusline 规范

## 1. Final Decisions

- `status02` 由 Rust renderer 持有；`status01` 是 fallback。
- 当前实现使用 CLI + tmux option cache，不使用 daemon。
- `StatusRuntime` 负责 read snapshot、resolve context、render components、compose、commit。
- component 不持有 `StatusRuntime`，不直接读写 tmux。
- 每个 component 必须实现 `snapshot` 和 `render`。
- component 自己维护 snapshot、bounded cache、刷新策略和 degrade 策略。
- `Tick` 是 render event，由 runtime 统一驱动。
- CPU / memory / network 是三个独立 component；先只支持 macOS，其他平台隐藏。CPU 使用 native ticks，memory/network 暂用系统命令。
- tmux native window list 暂不重写。
- dynamic plugin 暂不实现，只保留稳定边界。

## 2. Status Modes

```text
01 -> top    status01
11 -> bottom status01
02 -> top    status02, Rust-owned
12 -> bottom status02, Rust-owned
```

兼容归一化：

```text
03 -> 01
04 -> 02
13 -> 11
14 -> 12
empty / unknown -> 01
```

`status02.tmux.conf` 只读 Rust cache：

```tmux
set -g status-left  "#{E:@GHC_SL_STATUS02_LEFT}"
set -g status-right "#{E:@GHC_SL_STATUS02_RIGHT}"
```

`status02` steady-state 不依赖 legacy bash renderers：

```text
session list  -> Rust component
duration      -> Rust component
layout        -> Rust runtime
metrics       -> Rust components
tick trigger  -> tmux #() launches ghc-tmux-status apply tick
```

Legacy shell helpers are retained for status01 fallback / rollback:

```text
script/session-status.sh -> status01
script/duration.sh       -> status01
script/status-layout.sh  -> legacy status02 rollback only
```

fallback：

```text
Rust binary missing -> status01
Rust apply failed   -> status01
mode 01/11          -> status01
mode 02/12          -> Rust status02 if available
```

## 3. Ownership

```text
tmux event / tick
  -> ghc-tmux-status
  -> TmuxAdapter.read_snapshot
  -> SessionGrouper.group
  -> LayoutEngine.resolve
  -> StatusRuntime.render
  -> Component.snapshot
  -> Component.render
  -> StatusComposer.compose
  -> CommitPlanner.plan
  -> TmuxAdapter.commit_plan
```

职责：

| Module              | Responsibility                         |
|---------------------|----------------------------------------|
| `TmuxAdapter`       | 唯一 tmux read/write 边界              |
| `StatusRuntime`     | pipeline orchestration                 |
| `StatusComponent`   | snapshot / bounded cache / render / degrade |
| `StatusComposer`    | compose `RenderedSegment`              |
| `CommitPlanner`     | delta commit planning                  |
| `MetricProvider`    | platform-specific metrics sampling     |

禁止依赖：

```text
StatusComponent -> StatusRuntime
StatusComponent -> TmuxAdapter
StatusComposer  -> ComponentCache internals
MetricProvider  -> TmuxAdapter
LayoutEngine    -> TmuxAdapter
SessionGrouper  -> TmuxAdapter
```

## 4. Platform

```rust
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Platform {
    Win,
    Wsl,
    Nix,
    Osx,
}

pub fn current_platform() -> Platform;
```

规则：

```text
macOS       -> Osx
Windows     -> Win
Linux + WSL -> Wsl
Linux       -> Nix
Other Unix  -> Nix
```

约束：

- platform 只检测一次。
- 只有 `platform` module 可以做 OS detection。
- 其他模块只依赖 `Platform`。

## 5. Events

```rust
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub enum RenderEventKind {
    Tick,
    ThemeLoaded,
    ClientResized,
    SessionChanged,
    SessionCreated,
    SessionClosed,
    SessionRenamed,
    ManualApply,
}

pub struct RenderEvent {
    pub kind: RenderEventKind,
}
```

规则：

- `Tick` / `ThemeLoaded` / `ManualApply` 给所有 registered components 一次刷新机会。
- 非周期事件由 component 根据 `interests` 和 cache policy 自行决定是否取新 snapshot。
- component 可以复用 bounded cache，但不缓存 generic rendered rich_text。
- cache missing 时可以 fresh snapshot。
- 每次 event 后统一 compose final statusline。

## 6. Component Contract

```rust
pub trait StatusComponent {
    fn id(&self) -> &'static str;
    fn interests(&self) -> ComponentInterests;

    fn snapshot(
        &mut self,
        context: &RenderContext,
        event: &RenderEvent,
        cache: &mut dyn ComponentCache,
    ) -> AppResult<()>;

    fn render(&self, context: &RenderContext) -> AppResult<RenderedSegment>;
}
```

```rust
pub enum ComponentInterests {
    Static,
    All,
    Events(&'static [RenderEventKind]),
    Periodic { interval_secs: u64 },
}
```

```rust
pub struct RenderedSegment {
    pub literal_text: String,
    pub rich_text: String,
}
```

约束：

- `snapshot` 负责取数、bounded cache、stale 判断和 degrade。
- `render` 负责把 component 内部 snapshot 转成 tmux format。
- `literal_text` 是纯文本，用于宽度计算。
- `rich_text` 是 tmux statusline fragment。
- core 不读 component 内部 snapshot。

## 7. Cache

component cache：

```text
@GHC_STATUS_COMPONENT_CACHE_{component_id}
```

final row cache：

```text
@GHC_SL_STATUS02_LEFT
@GHC_SL_STATUS02_RIGHT
@GHC_SL_STATUS02_SESSION_FORMAT
@GHC_SL_STATUS02_CURRENT_FORMAT
@GHC_SL_LAYOUT
```

规则：

- component cache 是 single-slot bounded payload。
- 不缓存 generic rendered rich_text。
- component 只写自己的 cache。
- final row cache 只由 renderer 写。
- compose 完整成功后才 commit。
- commit 使用 delta plan，只写变化的长 option。
- final cache 相同且 component cache 无变化则 no-op。
- optional component 失败：stale cache -> hidden -> continue。
- required component 失败：abort current commit，保留上一版 statusline。

## 8. Session Grouping

status02 session list 只展示当前 session 所在 group。

```text
_popup@* current -> all _popup@* sessions
agent current    -> all agent sessions
G{n}-* current   -> all same G{n}-* sessions
normal current   -> all normal sessions
```

normal sessions exclude：

```text
_popup@*
agent sessions
G{digits}-*
```

agent session：

```text
{claude|codex|gemini}-{non-empty ascii hex suffix}
```

## 9. Layout

adaptive status 只作用于 `02` 和 `12`。

```text
02 -> top
12 -> bottom
```

规则：

```text
local status off   -> no-op
session_count <= 1 -> wide, one row, no session list
width >= 200       -> wide, one row
otherwise          -> narrow, two rows
invalid width      -> wide
```

commit target：

```text
wide   -> status on
narrow -> status 2
```

layout key：

```text
{mode}:{wide|narrow}
```

## 10. Rows

wide：

```text
status-left  = @GHC_SL_STATUS02_LEFT
status-right = @GHC_SL_STATUS02_RIGHT
status       = on
```

narrow：

```text
status-format[0] = @GHC_SL_STATUS02_SESSION_FORMAT
status-format[1] = @GHC_SL_STATUS02_CURRENT_FORMAT
status           = 2
```

约束：

- 保留 tmux native `#{W:...}` window list。
- 不重写 `window-status-format`。
- 不重写 `window-status-current-format`。

## 11. CLI

```text
ghc-tmux-status apply
ghc-tmux-status render status02
ghc-tmux-status layout <mode> <status> <width> <session-count>
ghc-tmux-status dump-state
```

语义：

| Command           | Meaning                         |
|-------------------|---------------------------------|
| `apply`           | read live snapshot, render, commit |
| `render status02` | print rendered status02 output  |
| `layout`          | pure layout calculation         |
| `dump-state`      | print debug snapshot/state      |

## 12. Metrics Components

components：

```text
CpuComponent
MemoryComponent
NetworkComponent
```

显示内容：

```text
CPU 12%  MEM 43%  ↓1.2M ↑80K
```

平台支持：

```text
Osx -> supported
Win -> hidden
Wsl -> hidden
Nix -> hidden
```

module：

```text
src/platform.rs
src/metric/mod.rs
src/metric/darwin.rs
src/metric/unsupported.rs
src/component/cpu.rs
src/component/memory.rs
src/component/network.rs
```

provider：

```rust
pub trait MetricsProvider {
    fn sample_cpu(&self) -> AppResult<CpuSnapshot>;
    fn sample_memory(&self) -> AppResult<MemorySnapshot>;
    fn sample_network(&self, previous: Option<&NetworkSample>) -> AppResult<NetworkSnapshot>;
}
```

macOS source：

```text
CPU     -> macOS CPU counter or lightweight command
Memory  -> vm_stat + sysctl hw.memsize
Network -> netstat -bn -I <interface>
```

network speed：

```text
rx_speed = (current_rx_bytes - previous_rx_bytes) / elapsed_seconds
tx_speed = (current_tx_bytes - previous_tx_bytes) / elapsed_seconds
```

规则：

- 默认 interface：`en0`。
- 允许未来通过 tmux option 覆盖 interface。
- counter reset / negative delta：本次 speed = `0`，刷新 cache。
- unsupported / parse failure：隐藏对应 component。

## 13. Theme

新增 theme variable 必须修改：

```text
/Users/wanchenfang/.config/guanghechen/asset/theme/app/tmux.hbs
```

然后执行：

```fish
fish -c "ghc-theme gen && ghc-theme apply"
```

Rust renderer 只引用 `@GHC_*` tmux options，不硬编码最终颜色。

## 14. Degrade

```text
platform unsupported        -> hide platform component
optional component failed   -> stale cache or hidden
required component failed   -> abort current commit
invalid width               -> wide layout
session list read failed    -> one-row without session list
tmux commit failed          -> keep previous visible statusline
local status off            -> no status/layout writes
```

component 不允许因为坏系统数据 panic。

## 15. Minimal Core

core 必须在无 optional component 时可运行。

必备能力：

```text
read tmux snapshot
resolve session group
resolve adaptive layout
render built-in components
compose rows
diff final cache
batch commit
fallback status01
```

built-in components：

```text
host
session_list
prefix_indicator
session_bell
duration
date
time
fullscreen
window_id
```

optional components：

```text
cpu
memory
network
```

## 16. Tests

必须覆盖：

```text
mode normalization
single-session layout
multi-session wide/narrow layout
top/bottom position
local status off
normal / popup / agent / G{n} session grouping
literal_text width
component cache reuse
final cache no-op
Rust missing / apply failed fallback
macOS cpu/memory/network success / parse failure / counter reset
```
