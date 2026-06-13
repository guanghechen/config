# Status Right Dynamic Length Architecture Spec

## 1. Module Boundary (SRP)

| Module | Responsibility | Public Ports | Private Runtime |
|--------|----------------|--------------|-----------------|
| `widget::pill` | Shared literal placeholders for tmux pill glyphs | `pill_literal`, `conditional_pill_literal`, `prefix_literal` | glyph placeholder constants |
| widgets | Render rich text and faithful literal shadows | `StatusWidget::render` | widget-specific body text |
| `status_length` | Compute bounded tmux length options | `status_left_length`, `status_right_length` | width formula |
| `composer` | Decide no-op based on rendered outputs and length options | `cache_matches` | snapshot option comparison |
| `commit` | Write changed tmux options | `CommitPlanner::plan` | `TmuxCommandPlan` |
| `tmux` | Snapshot tmux option state | `read_snapshot` | `display-message` parsing |

## 2. Dependency Graph

- one-way dependencies: `widget -> model/status_widget/util`, `status_length -> model/util`, `composer -> status_length`, `commit -> status_length`, `tmux -> model`.
- forbidden reverse dependencies: `status_length` must not call tmux; widgets must not call commit/runtime.

## 3. Interaction Lifecycle Model

### Lifecycle

- init: theme seeds `status-right-length=84`.
- start: status02 runtime renders widgets and computes right length.
- stop: commit writes changed tmux options and refreshes client.
- dispose: no persistent process; option remains in tmux server.

### Interaction Transitions

| From | To | Event | Guard | Timeout | Error Handling |
|------|----|-------|-------|---------|----------------|
| Runtime | Widgets | apply/tick/theme | active status02 | process lifetime | propagate render error |
| Runtime | CommitPlanner | rendered status | snapshot available | process lifetime | produce no-op plan when unchanged |
| CommitPlanner | TmuxAdapter | stale length | tmux alive | process lifetime | propagate `TmuxCommand` error |

## 4. Interface Contracts

| Port | Input | Output | Idempotency | Timeout | Error Contract |
|------|-------|--------|-------------|---------|----------------|
| `pill_literal` | body literal | full pill literal | pure | none | no error |
| `status_right_length` | rendered status + context | string length option | pure | none | no error |
| `cache_matches` | snapshot + rendered status | bool | pure | none | no error |
| `CommitPlanner::plan` | rendered status + context | tmux plan | idempotent | none | no error |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: status02 render and dynamic length commit work without optional plugins.
- works without optional plugins: true

### Plugin Contract

No plugin architecture is introduced.

## 6. Observability and Degrade Strategy

- `render status02` prints `width.status-right` and can be used to diagnose length drift.
- If runtime fails before convergence, theme seed `84` remains as fallback.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
