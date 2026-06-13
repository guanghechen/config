# Widget Lifecycle Contract Architecture Spec

## 1. Module Boundary (SRP)

| Module | Responsibility | Public Ports | Private Runtime |
|--------|----------------|--------------|-----------------|
| `status_widget` | Object-safe runtime port and lifecycle adapters | `StatusWidget`, `TemplateWidget`, `ComputedWidget`, `CachedMetricWidget`, adapter constructors | TTL/cache orchestration |
| `widget::*` | Concrete widget-specific rendering or sampling logic | one lifecycle trait per widget | rich/literal formatting helpers |
| `composer` | Concatenate widget outputs | `render_widgets` | adapter dispatch |
| `runtime` | Select widget placement and assemble status02 rows | `StatusRuntime` | concrete adapter construction |
| `cache` | Persist cross-tick widget state in tmux options | `WidgetCache`, `TmuxWidgetCache` | option naming |
| `metric` | Platform-specific expensive sampling | `MetricsProvider` | subprocess/native calls |

## 2. Dependency Graph

- one-way dependencies: `runtime -> widget/status_widget`, `composer -> status_widget/cache`, `status_widget -> cache/model/util`, `widget -> status_widget/model/metric/util`.
- forbidden reverse dependencies: widgets must not call runtime/composer/commit/tmux; `status_widget` must not depend on concrete widgets; metric providers must not depend on widgets.

## 3. Interaction Lifecycle Model

### Lifecycle

- init: runtime constructs short-lived lifecycle adapters for each placement.
- start: composer asks each adapter to refresh according to lifecycle and event.
- stop: composer asks each adapter to render a cheap segment.
- dispose: process exits; only `WidgetCache` option values persist.

### Interaction Transitions

| From | To | Event | Guard | Timeout | Error Handling |
|------|----|-------|-------|---------|----------------|
| Runtime | Composer | active status02 apply | widget adapters constructed | process lifetime | propagate error |
| Composer | StatusWidget adapter | refresh | lifecycle-specific | process lifetime | propagate render/cache errors; metric adapter degrades on sample error |
| StatusWidget adapter | Concrete widget | render/sample | contract-specific | process lifetime | sample failure can fall back to cache |

## 4. Interface Contracts

| Port | Input | Output | Idempotency | Timeout | Error Contract |
|------|-------|--------|-------------|---------|----------------|
| `TemplateWidget::render_template` | `RenderContext` | `RenderedSegment` | pure/cheap | none | propagate error |
| `ComputedWidget::render_computed` | `RenderContext` | `RenderedSegment` | cheap/no external IO | none | propagate error |
| `CachedMetricWidget::sample` | previous snapshot | new snapshot | controlled by TTL | process lifetime | adapter falls back to cached snapshot on error |
| `CachedMetricWidget::render_snapshot` | cached/new snapshot | `RenderedSegment` | pure/cheap | none | no error |
| `StatusWidget::refresh` | context/event/cache | adapter-local state | idempotent for fresh cache | process lifetime | propagate non-metric errors |
| `StatusWidget::render` | context | `RenderedSegment` | pure/cheap | none | propagate error |

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities: status02 render works with template/computed/cached-metric widgets.
- works without optional plugins: true

### Plugin Contract

No plugin architecture is introduced. Lifecycle adapters are compile-time contracts, not dynamic plugins.

## 6. Observability and Degrade Strategy

- Existing `render status02` and `dump-state` remain available.
- Cached metrics degrade to last-known values on sampling failure.
- No daemon is introduced; next tick/hook is the retry mechanism.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
