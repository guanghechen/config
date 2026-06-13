# Widget Lifecycle Contract Draft

## 1. Problem Statement

`status-interval=1` makes tmux redraw every second so native `%H:%M:%S` can advance. The Rust `apply tick` path also runs once per second and currently constructs every widget, calls `snapshot` according to a coarse policy, renders every widget, and then usually no-ops at commit time.

The current performance is acceptable, but the `StatusWidget` contract is too permissive for long-term maintenance: a new widget can accidentally put subprocess, network, or file-system work in a path that runs every second.

## 2. Context and Constraints

- The clock must remain native tmux strftime; Rust must not compute current seconds for display.
- Existing behavior and visual output must remain unchanged.
- Expensive metric collection must stay bounded by TTL even when `status-interval=1`.
- The runtime is a short-lived CLI process; widget instance fields do not persist across ticks.
- Cross-tick state is persisted only through tmux options via `WidgetCache`.
- Avoid daemon/plugin architecture for this phase.

## 3. Open Questions

| Question | Options | Decision | Rationale |
|----------|---------|----------|-----------|
| How should widgets declare cost? | One free-form trait / lifecycle enum + adapters / daemon scheduler | Lifecycle adapters | Makes the fast path enforceable without adding a persistent process. |
| Where should TTL logic live? | Each metric widget / shared adapter | Shared `CachedMetric` adapter | New metric widgets fill in sampling and cache encoding only; TTL is enforced centrally. |
| Should tick preflight gate be included now? | Yes / No | No | It is trigger optimization, not required for the stable widget contract. |

## 4. Risk Notes

| Risk | Trigger | Evidence | Impact | Mitigation |
|------|---------|----------|--------|------------|
| Hidden expensive render | Future widget calls `Command` in render | Current trait permits arbitrary render body | 1s interval amplifies work | Separate Template/Computed/CachedMetric contracts and document render as cheap/no external IO. |
| Behavior drift during refactor | Adapter migration changes rich/literal text | Many style-sensitive widgets | Visual regression or length drift | Preserve existing render helpers and tests; add adapter behavior tests. |
| Cache semantics drift | Metric TTL logic moves to adapter | CPU/memory/network currently duplicate TTL | Over-sampling or stale output | Generic tests for TTL fresh/stale paths. |

## 5. Draft Decisions

- Keep `StatusWidget` as the object-safe runtime port, but make it an internal adapter target.
- New concrete widgets should implement one of:
  - `TemplateWidget`: native tmux format, no refresh/cache.
  - `ComputedWidget`: cheap context/process-local computation, no cache.
  - `CachedMetricWidget`: expensive sampling behind shared TTL/cache/fallback logic.
- `render()` remains called every `apply`, but adapter contracts make it cheap by construction.
- Tick preflight gate is deferred to a later phase after lifecycle contracts are stable.
