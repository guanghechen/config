# Statusline Runtime Refactor Architecture Spec

## 1. Module Boundary (SRP)

| Module              | Responsibility                         | Public Ports                         | Private Runtime              |
|---------------------|----------------------------------------|--------------------------------------|------------------------------|
| `main`              | CLI parse                              | `apply EVENT`, `render status02`     | argv parsing                 |
| `runtime`           | orchestrate read/resolve/render/commit | `StatusRuntime::apply`               | component registry           |
| `tmux`              | only tmux IO boundary                  | `read_snapshot`, `commit_plan`       | command execution/parsing    |
| `layout`            | resolve row plan                       | `LayoutEngine::resolve`              | width/mode rules             |
| `session_group`     | derive current session group           | `SessionGrouper::group`              | grouping rules               |
| `component`         | component plugins                      | `StatusComponent`                    | snapshot/cache/degrade       |
| `cache`             | bounded cache slots                    | `ComponentCache`                     | option encoding              |
| `composer`          | assemble rows                          | `compose_status02`                   | component order              |
| `commit`            | build delta plan                       | `CommitPlanner::plan`                | changed-option detection     |
| `status_length`     | compute tmux status length budgets     | `status_left_length`                 | width/padding rules          |
| `metric`            | platform metrics provider              | `MetricsProvider`                    | macOS native CPU + commands  |
| `platform`          | OS detection                           | `current_platform`                   | `OnceLock` detection         |

## 2. Dependency Graph

One-way dependencies:

```text
main -> runtime -> tmux
              -> layout
              -> session_group
              -> composer -> component -> cache
              -> composer -> status_length -> width
              -> commit -> status_length
component::metrics -> metric -> platform
```

Forbidden reverse dependencies:

```text
component -> runtime
component -> tmux
composer  -> tmux
commit    -> component internals
metric    -> tmux
layout    -> tmux
```

## 3. Interaction Lifecycle Model

### Lifecycle

- init: CLI builds `StatusRuntime` with static component registry。
- start: `apply(event)` reads snapshot and resolves context。
- stop: commit completes or no-op returns。
- dispose: process exits; persistent state only lives in tmux cache options。

### Interaction Transitions

| From              | To              | Event          | Guard                  | Timeout     | Error Handling              |
|-------------------|-----------------|----------------|------------------------|-------------|-----------------------------|
| CLI               | Runtime         | apply          | valid event            | process run | usage error                 |
| Runtime           | TmuxAdapter     | read_snapshot  | status02 candidate     | tmux default | abort apply                 |
| Runtime           | ComponentPlugin | snapshot       | component registered   | component-defined | stale/hidden/abort      |
| Runtime           | Composer        | compose        | outputs available      | in-process  | abort apply                 |
| Runtime           | CommitPlanner   | plan           | rendered status ready  | in-process  | abort apply                 |
| Runtime           | TmuxAdapter     | commit_plan    | plan non-empty         | tmux default | split retry then abort      |

## 4. Interface Contracts

| Port                       | Input                         | Output                  | Idempotency | Timeout       | Error Contract              |
|----------------------------|-------------------------------|-------------------------|-------------|---------------|-----------------------------|
| `StatusRuntime::apply`     | `RenderEvent`                 | `()`                    | yes         | one process   | returns `AppError`          |
| `TmuxAdapter::read_snapshot` | none                        | `TmuxSnapshot`          | yes         | tmux default  | parse/io error              |
| `StatusComponent::snapshot` | `RenderContext`, cache       | component snapshot      | yes         | component TTL | stale/hidden/error          |
| `StatusComponent::render`  | component snapshot            | `RenderedSegment`       | yes         | in-process    | render error                |
| `CommitPlanner::plan`      | snapshot, rendered, cache ops | `TmuxCommandPlan`       | yes         | in-process    | plan error                  |
| `status_length::status_left_length` | rendered status, context | tmux length string | yes | in-process | pure calculation            |
| `TmuxAdapter::commit_plan` | command plan                  | `()`                    | yes         | tmux default  | write error                 |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: host, native window list, time/date, layout, fallback。
- works without optional plugins: true。
- optional plugins: session list, fullscreen, window id, prefix, session bell, duration, cpu, memory, network。

### Plugin Contract

- manifest fields: `name`, `version`, `capabilities`, `compatibility`, `required`。
- lifecycle hooks: `on_load`, `snapshot`, `render`, `on_unload`。
- failure isolation: timeout guard by component policy, stale cache fallback, hidden fallback。
- load/unload: static registry includes/excludes components before render; no dynamic dylib loading。

## 6. Observability and Degrade Strategy

- `dump-state` prints mode/status/layout/session group/cache size summary。
- optional component failure does not fail core。
- required component failure aborts current commit and keeps previous statusline。
- cache size must be visible enough for manual diagnosis。
- command length retry must report concise error if split retry fails。
- `render status02` prints computed `status-left-length` for clipping diagnosis。

## 7. Open Decisions（唯一待定区）

| Topic               | Options                    | Owner   | Deadline | Blocking | Decision Rule             |
|---------------------|----------------------------|---------|----------|----------|---------------------------|
| dynamic plugin load | none / dylib / subprocess  | primary | later    | false    | only when third-party need |
