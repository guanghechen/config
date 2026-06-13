# Session Last Focus Architecture Spec

## 1. Module Boundary (SRP)

| Module | Responsibility | Public Ports | Private Runtime |
|--------|----------------|--------------|-----------------|
| `tmux.rs` | Read client last-session state with the snapshot | `TmuxAdapter::read_snapshot` | context parser |
| `model.rs` | Carry client last-session data | `TmuxSnapshot.client_last_session` | none |
| `widget/session_list.rs` | Render visible last-session marker | `SessionListWidget` | palette/body helpers |
| keymap conf | Bind last-session shortcut | `"`, `M-'"'` | tmux `switch-client -l` |
| `guanghechen` theme hbs | Define semantic last-session color | `@GHC_SL_FG_SESSION_ITEM_LAST` | theme palette |

## 2. Dependency Graph

- one-way dependencies: `tmux -> model`, `widget -> model/status_widget`, keymap -> tmux native command.
- forbidden reverse dependencies: `model` must not depend on widget/tmux; widget must not invoke tmux; Rust must not own a separate session stack.

## 3. Interaction Lifecycle Model

### Lifecycle

- init: no Rust-owned state initialization.
- start: tmux updates `client_last_session` during session switches.
- stop: no cleanup.
- dispose: no persistent state.

### Interaction Transitions

| From | To | Event | Guard | Timeout | Error Handling |
|------|----|-------|-------|---------|----------------|
| tmux client | snapshot | status apply | client context available | tmux command timeout inherited from process | propagate apply error |
| snapshot | render | status02 active | group visible | none | render without marker if absent |
| keymap | tmux switch | keypress | last session exists | tmux native | tmux displays error/message |

## 4. Interface Contracts

| Port | Input | Output | Idempotency | Timeout | Error Contract |
|------|-------|--------|-------------|---------|----------------|
| `parse_context_line` | context line | width/current/last/host/created tuple | deterministic | none | parse error on invalid marker |
| `render_session_list` | `RenderContext` | `RenderedSegment` | deterministic | none | infallible wrapper |
| key binding | keypress | session switch | native tmux | native tmux | native tmux error |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: status02 renders without a last marker when `client_last_session` is empty.
- works without optional plugins: true

### Plugin Contract

No plugin boundary is introduced. tmux is the source of truth for last-session state.

## 6. Observability and Degrade Strategy

- `render status02` exposes the changed rich text and literal width; `dump-state` reports `client_last_session`.
- Missing `client_last_session` degrades to no marker.
- Multi-client global-status mismatch is accepted as part of the current runtime model.

## 7. Open Decisions（唯一待定区）

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
