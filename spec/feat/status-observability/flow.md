# Status Observability Flow Spec

## 1. Scope

Add opt-in runtime tracing and read-only dump-state observability for status02 performance analysis.

## 2. Boundary

- Input Boundary: CLI command, environment variable `GHC_TMUX_STATUS_TRACE`, tmux snapshot options.
- Output Boundary: stderr trace lines when enabled; stdout dump-state fields.

## 3. Dataflow State Machine

### States

| State | Owner | Read Set | Write Set | Side Effects |
|-------|-------|----------|-----------|--------------|
| TraceConfigRead | observability | process environment | none | none |
| ApplyPhaseMeasured | runtime | `Instant`, phase boundaries | stderr trace | stderr only when enabled |
| MetricRefreshObserved | status widget adapter | event, cache, TTL | stderr trace | stderr only when enabled |
| DumpStateRendered | runtime | tmux snapshot options | stdout dump | stdout only |

### Transitions

| From | To | Trigger | Guard | On Failure |
|------|----|---------|-------|------------|
| CLIApply | TraceConfigRead | any apply event | none | tracing disabled on missing env |
| TraceConfigRead | ApplyPhaseMeasured | trace enabled | active/inactive runtime path | continue without trace if formatting fails impossible |
| CachedMetricRefresh | MetricRefreshObserved | trace enabled | metric lifecycle | continue normal refresh |
| CLIDumpState | DumpStateRendered | `dump-state` | active status02 context | propagate existing inactive error |

## 4. Failure Path

- retry: next manual command or tick can trace again.
- rollback: no persistent writes.
- degrade: invalid/missing metric cache is reported as invalid/missing.
- abort: existing tmux snapshot errors propagate.

## 5. Invariants

- Default output is unchanged when `GHC_TMUX_STATUS_TRACE` is unset/false/0.
- Trace output goes to stderr only.
- `dump-state` does not sample metrics or commit options.
- Metric cache freshness uses the same widget ids and TTLs as cached metric widgets.

## 6. Test Matrix

| Case | Expected |
|------|----------|
| Metric cache missing | dump-state helper reports missing. |
| Metric cache invalid timestamp | dump-state helper reports invalid. |
| Metric cache fresh/stale | helper computes age and freshness with TTL. |
| CachedMetric trace path disabled | behavior remains covered by lifecycle tests. |
| Full crate verification | cargo test/clippy/build pass. |

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
