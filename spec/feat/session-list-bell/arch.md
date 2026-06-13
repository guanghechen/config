# Session List Bell Architecture Spec

## 1. Module Boundary (SRP)

| Module | Responsibility | Public Ports | Private Runtime |
|--------|----------------|--------------|-----------------|
| `tmux.rs` | Read tmux snapshot including per-session bell flag | `TmuxAdapter::read_snapshot` | `list-sessions` parser |
| `model.rs` | Carry session snapshot data | `SessionInfo.has_bell` | none |
| `session/*` | Group/order/focus/swap sessions | pure functions over `SessionInfo` | none |
| `widget/session_list.rs` | Render session list body and literal width shadow | `SessionListWidget` | item palette/body helpers |
| `runtime.rs` | Orchestrate snapshot/render/commit cadence | existing apply flow | one-second tick |

## 2. Dependency Graph

- one-way dependencies: `tmux -> model`, `session -> model`, `widget -> model/status_widget`, `runtime -> tmux/session/widget/commit`.
- forbidden reverse dependencies: `model` must not depend on tmux/widget; `session` must not invoke tmux; `widget/session_list` must not read tmux directly.

## 3. Interaction Lifecycle Model

### Lifecycle

- init: no new initialization.
- start: status02 existing tick invokes runtime.
- stop: leaving status02 removes tick through existing theme load path.
- dispose: no persistent resources.

### Interaction Transitions

| From | To | Event | Guard | Timeout | Error Handling |
|------|----|-------|-------|---------|----------------|
| tmux alert state | snapshot | tick/theme/manual/session event | status02 active | tmux command timeout inherited from process | propagate apply error |
| snapshot | render | valid snapshot | visible sessions > 1 | none | render empty if list suppressed |
| render | commit | changed rich text or length | commit planner diff | tmux command timeout inherited from process | keep prior options |

## 4. Interface Contracts

| Port | Input | Output | Idempotency | Timeout | Error Contract |
|------|-------|--------|-------------|---------|----------------|
| `parse_snapshot_output` | tmux output text | `TmuxSnapshot` | deterministic | none | `AppError::TmuxParse` on invalid sections |
| `render_session_list` | `RenderContext` | `RenderedSegment` | deterministic | none | infallible wrapper |
| `CommitPlanner::plan` | rendered status + snapshot options | tmux command plan | changed-only | none | no side effects |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: status02 still renders without bell data; missing bell field degrades to `false`.
- works without optional plugins: true

### Plugin Contract

No plugin boundary is introduced. tmux is the only external capability and failure is isolated by the existing apply error path.

## 6. Observability and Degrade Strategy

- `dump-state` and trace inherit the changed session rich text/length behavior from existing observability.
- Missing or malformed bell flag degrades to no bell marker.
- Bell state convergence can be live-smoked by triggering a bell in a non-focused session and then focusing the alerted window.

## 7. Open Decisions（唯一待定区）

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
