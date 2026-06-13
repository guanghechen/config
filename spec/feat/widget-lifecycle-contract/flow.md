# Widget Lifecycle Contract Flow Spec

## 1. Scope

Define the dataflow for rendering status02 widgets under a stable lifecycle contract. This phase covers widget refresh/render orchestration only; tmux trigger cadence remains unchanged.

## 2. Boundary

- Input Boundary: `RenderContext`, `RenderEvent`, tmux-backed `WidgetCache`.
- Output Boundary: `RenderedSegment` values and pending cache option writes.

## 3. Dataflow State Machine

### States

| State | Owner | Read Set | Write Set | Side Effects |
|-------|-------|----------|-----------|--------------|
| EventReceived | runtime | CLI event | none | none |
| SnapshotLoaded | tmux adapter | tmux server | `TmuxSnapshot` | `tmux display-message/show/list-sessions` |
| WidgetRefreshEvaluated | widget adapter | event, cache, lifecycle | adapter-local snapshot | optional metric sampling |
| WidgetRendered | widget adapter | context, adapter-local snapshot | `RenderedSegment` | none |
| StatusComposed | composer | rendered segments | `RenderedStatus` | none |
| CommitPlanned | commit planner | rendered status, context, cache diff | `TmuxCommandPlan` | none |

### Transitions

| From | To | Trigger | Guard | On Failure |
|------|----|---------|-------|------------|
| EventReceived | SnapshotLoaded | `apply` | tmux available | abort with error |
| SnapshotLoaded | WidgetRefreshEvaluated | active status02 | widget lifecycle selected | cached metric falls back to old cache on sample error |
| WidgetRefreshEvaluated | WidgetRendered | all widgets | render contract is cheap/no external IO | abort with render error |
| WidgetRendered | StatusComposed | segment concatenation | all segments valid | abort with render error |
| StatusComposed | CommitPlanned | compare snapshot options | not ThemeLoaded no-op allowed | no-op plan when unchanged |

## 4. Failure Path

- retry: none in-process; next tick/hook retries naturally.
- rollback: no partial widget state persists except cache writes included in commit plan.
- degrade: cached metrics use last-known cache if sampling fails.
- abort: tmux snapshot/commit errors propagate to CLI exit status.

## 5. Invariants

- `TemplateWidget` never reads or writes `WidgetCache`.
- `ComputedWidget` never reads or writes `WidgetCache`.
- `CachedMetricWidget::sample` is called only when refresh event and TTL require it.
- `render` paths do not perform external IO by contract.
- Widget instance state is process-local; cross-tick state must go through `WidgetCache`.
- Visual rich text and literal width shadows remain behavior-compatible with the pre-refactor output.

## 6. Test Matrix

| Case | Expected |
|------|----------|
| Template adapter render | Calls only template render; no cache access required. |
| Computed adapter render | Calls only computed render; no cache access required. |
| Cached metric fresh cache | Does not call sample; renders cached snapshot. |
| Cached metric stale cache | Calls sample once; writes pending cache. |
| Cached metric sample failure | Renders cached snapshot; no panic. |
| Existing status02 tests | Rich/literal output invariants remain green. |

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
