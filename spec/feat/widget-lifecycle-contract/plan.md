# Widget Lifecycle Contract Implementation Plan

## 1. Scope Mapping

| Design Ref | Design Source | Code Target | Test Target |
|------------|---------------|-------------|-------------|
| Lifecycle adapters | arch.md §1/§4 | `src/status_widget.rs` | adapter unit tests |
| Metric TTL centralization | flow.md §5 | `src/widget/{cpu,memory,network}.rs` | cache fresh/stale tests |
| Behavior parity | flow.md §6 | existing widgets/runtime | existing widget/composer/status_length tests |

## 2. Work Breakdown

| Step | Design Ref | Change Area | Inputs | Outputs | Verification | Code Target |
|------|------------|-------------|--------|---------|--------------|-------------|
| 1 | Lifecycle adapters | trait API | old `StatusWidget` | adapter constructors and contracts | cargo test | `status_widget.rs` |
| 2 | Template widgets | cheap tmux-template widgets | render bodies | `TemplateWidget` impls | existing tests | `widget/{date,time,fullscreen,window_id,prefix_indicator,session_bell}.rs` |
| 3 | Computed widgets | context/local cheap widgets | render bodies | `ComputedWidget` impls | existing tests | `widget/{host,session_list,duration}.rs` |
| 4 | Cached metrics | metric widgets | cache parse/encode/sample/render | `CachedMetricWidget` impls | fresh/stale adapter tests | `widget/{cpu,memory,network}.rs` |
| 5 | Runtime wiring | placement construction | exported constructors | behavior-equivalent render | cargo test/clippy/build | `runtime.rs`, `widget/mod.rs` |

## 3. Acceptance Criteria

- `cargo test` passes.
- `cargo clippy -- -D warnings` passes.
- `cargo build --release` passes.
- Existing status02 render output remains behavior-compatible.
- Cached metric sampling is centrally TTL-gated.
- New widgets can implement one lifecycle trait instead of free-form `snapshot/render`.

## 4. Rollback Plan

Revert this feature commit. The previous `StatusWidget` implementation is self-contained and does not require data migration; existing cache option names remain unchanged.

## 5. Progress

| Step | Status | Notes |
|------|--------|-------|
| 1 | completed | Lifecycle adapters implemented in `status_widget.rs`. |
| 2 | completed | Template widgets migrated. |
| 3 | completed | Computed widgets migrated. |
| 4 | completed | Cached metric widgets migrated to shared TTL/cache adapter. |
| 5 | completed | Runtime wiring uses lifecycle adapters; verification passed. |
