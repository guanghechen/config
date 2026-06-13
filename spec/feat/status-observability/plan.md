# Status Observability Implementation Plan

## 1. Scope Mapping

| Design Ref | Design Source | Code Target | Test Target |
|------------|---------------|-------------|-------------|
| Trace helper | arch.md §1 | `src/observability.rs` | unit tests for duration formatting |
| Apply timing | flow.md §3 | `src/runtime.rs` | smoke trace command |
| Metric refresh trace | flow.md §3 | `src/status_widget.rs` | existing CachedMetric tests |
| Dump cache freshness | flow.md §5 | `src/runtime.rs` | unit tests for cache state helper |

## 2. Work Breakdown

| Step | Design Ref | Change Area | Inputs | Outputs | Verification | Code Target |
|------|------------|-------------|--------|---------|--------------|-------------|
| 1 | Trace helper | utility module | env/duration | trace functions | cargo test | `observability.rs`, `main.rs` |
| 2 | Apply timing | runtime apply | phase boundaries | stderr trace | manual env smoke | `runtime.rs` |
| 3 | Metric trace | CachedMetric adapter | cache/event/TTL | stderr trace | cargo test | `status_widget.rs` |
| 4 | Dump summary | dump-state | snapshot options | metric cache lines | unit tests | `runtime.rs` |

## 3. Acceptance Criteria

- Default status output unchanged when trace env is unset.
- `GHC_TMUX_STATUS_TRACE=1 ... apply manual-apply` prints phase timing to stderr.
- `dump-state` reports metric cache freshness without sampling.
- `cargo test`, `cargo clippy -- -D warnings`, and `cargo build --release` pass.

## 4. Rollback Plan

Revert this feature commit. No data migration or tmux option cleanup is required.

## 5. Progress

| Step | Status | Notes |
|------|--------|-------|
| 1 | completed | Added env-gated trace helper. |
| 2 | completed | Runtime apply phase timing traces added. |
| 3 | completed | CachedMetric refresh decision traces added. |
| 4 | completed | dump-state metric cache freshness added. |
