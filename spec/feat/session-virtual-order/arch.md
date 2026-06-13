# Session Virtual Order Architecture Spec

## 1. Module Boundary (SRP)

| Module | Responsibility | Public Ports | Private Runtime |
|--------|----------------|--------------|-----------------|
| `session::group` | Group tmux sessions by current context | `SessionGrouper`, `same_session_group` | regex/name rules |
| `session::item` | Session command value types and typed outcomes | `FocusTarget`, `MoveDirection`, `SwapOutcome` | parse aliases |
| `session::list` | Pure virtual ordering, focus, and swap math for a visible session list | `ordered_sessions`, `swap_current`, `focus_target` | id normalization |
| `runtime` | Orchestrate tmux snapshot, ordering, side effects | `apply`, `focus_session`, `swap_session` | `TmuxAdapter` |
| `tmux` | Execute tmux commands and parse snapshot | `read_snapshot`, `switch_client`, `set_global_option`, `display_message` | `Command::new("tmux")` |
| `widget::session_list` | Render ordered group | `SessionListWidget` | tmux rich text formatting |
| scripts/keymap | Bind user shortcuts to Rust commands | `focus-session.sh`, `swap-session.sh` | binary fallback |

## 2. Dependency Graph

- one-way dependencies: `tmux -> model`, `session -> model`, `runtime -> tmux/session/widget/composer/commit`, `widget -> model/status_widget`.
- forbidden reverse dependencies: `session` must not call `tmux`; `widget` must not call `tmux`; `util` must not depend on domain modules.

## 3. Interaction Lifecycle Model

### Lifecycle

- init: tmux loads keymaps/scripts; Rust binary available after release build.
- start: user invokes focus/swap shortcut or status runtime render.
- stop: command completes after switch/order write/refresh.
- dispose: no long-running process; state remains in tmux global option.

### Interaction Transitions

| From | To | Event | Guard | Timeout | Error Handling |
|------|----|-------|-------|---------|----------------|
| KeyPress | RustCLI | key binding | binary exists | tmux run-shell default | display fallback message |
| RustCLI | Runtime | parsed command | target valid | process lifetime | usage error |
| Runtime | TmuxAdapter | side effect | tmux server alive | process lifetime | propagate `TmuxCommand` error |
| Runtime | Apply | swap success | order changed | process lifetime | normal apply fallback |

## 4. Interface Contracts

| Port | Input | Output | Idempotency | Timeout | Error Contract |
|------|-------|--------|-------------|---------|----------------|
| `ordered_sessions` | sessions + order ids | ordered sessions | pure | none | no panic on stale ids |
| `swap_current` | live sessions + visible group + current + direction | new order or boundary | pure | none | typed no-op |
| `focus_target` | ordered group + current + target | target id or none | pure | none | typed no-op |
| `session swap` CLI | prev/next | tmux order update | idempotent at boundary | process | `AppError` |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: status render/focus/swap work without optional plugins.
- works without optional plugins: true

### Plugin Contract

No plugin architecture is introduced for this feature.

## 6. Observability and Degrade Strategy

- Boundary/no target cases use `tmux display-message`.
- If binary is missing, scripts display a short fallback message or use legacy focus behavior.
- `dump-state` may later include session order if needed.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
