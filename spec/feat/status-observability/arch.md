# Status Observability Architecture Spec

## 1. Module Boundary (SRP)

| Module | Responsibility | Public Ports | Private Runtime |
|--------|----------------|--------------|-----------------|
| `observability` | Env-gated trace helpers and duration formatting | `trace_enabled`, `trace_line`, `duration_ms` | env parsing |
| `runtime` | Apply phase timing and dump-state cache summary | `apply`, `dump_state` | `Instant` measurements |
| `status_widget` | Cached metric refresh decision trace | `CachedMetric` adapter | cache-hit/sample trace |
| `widget::*` | Provide lifecycle TTL/id | lifecycle trait impls | no tracing logic |

## 2. Dependency Graph

- one-way dependencies: `runtime -> observability/status_widget/widget`, `status_widget -> observability`, `observability -> std`.
- forbidden reverse dependencies: observability must not call tmux/runtime/widget; widgets should not depend on observability directly.

## 3. Interaction Lifecycle Model

### Lifecycle

- init: trace config is read on demand from process environment.
- start: apply/dump-state executes normally.
- stop: trace/dump lines are emitted to stderr/stdout respectively.
- dispose: no persistent observability state.

### Interaction Transitions

| From | To | Event | Guard | Timeout | Error Handling |
|------|----|-------|-------|---------|----------------|
| Runtime | Observability | apply phase boundary | trace enabled | none | no error |
| CachedMetric | Observability | refresh decision | trace enabled | none | no error |
| Runtime | stdout | dump-state | active status02 | process lifetime | propagate snapshot error |

## 4. Interface Contracts

| Port | Input | Output | Idempotency | Timeout | Error Contract |
|------|-------|--------|-------------|---------|----------------|
| `trace_enabled` | env | bool | pure for process env | none | no error |
| `trace_line` | scope + message | stderr line if enabled | no persistent state | none | no error |
| `duration_ms` | `Duration` | f64 milliseconds | pure | none | no error |
| `dump_state` metric cache summary | snapshot options | stdout fields | read-only | process lifetime | parse invalid as invalid state |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: status02 works with tracing disabled.
- works without optional plugins: true

### Plugin Contract

No plugin architecture is introduced.

## 6. Observability and Degrade Strategy

- Enable trace with `GHC_TMUX_STATUS_TRACE=1 ghc-tmux-status apply manual-apply`.
- `dump-state` includes metric cache state without sampling.
- Invalid cache values are reported, not fatal.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
