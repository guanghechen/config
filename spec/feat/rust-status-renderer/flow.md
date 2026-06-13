# Rust Status Renderer Flow Spec

## 1. Scope

This flow covers the status02 Rust render path: collecting tmux state, deriving the current session group, selecting wide/narrow layout, invoking components, composing cached status rows, committing tmux options, and letting tmux render the final statusline.

## 2. Boundary

- Input Boundary:
  - tmux events: theme load, client resize, client session change, session create/close/rename.
  - tmux state: `@GHC_SL_MODE`, `@GHC_SL_LAYOUT`, `status`, `client_width`, current session name, session list, generated theme options.
  - component cache state: component-owned cache entries under stable tmux option namespaces or later cache backend namespaces.
  - preserved native window formats: `window-status-format`, `window-status-current-format`, and `#{W:...}`.
- Output Boundary:
  - component outputs: `RenderedSegment { literal_text, rich_text }`.
  - tmux global options: layout cache and rendered status segment cache.
  - tmux status options: `status`, `status-position`, `status-justify`, `status-format[0]`, `status-format[1]`, `status-left`, `status-right`.
  - terminal status area rendered by tmux.

## 3. Dataflow State Machine

### States

| State              | Owner                  | Read Set                                             | Write Set                                      | Side Effects              |
|--------------------|------------------------|------------------------------------------------------|------------------------------------------------|---------------------------|
| EventReceived      | tmux hook / loader     | hook event, current client context                   | renderer invocation args                       | Spawns Rust CLI           |
| SnapshotCollected  | Rust `TmuxCollector`   | tmux mode, status, width, current session, sessions  | immutable `TmuxSnapshot`                       | tmux read commands        |
| GroupResolved      | Rust `SessionGrouper`  | `TmuxSnapshot.sessions`, current session             | `SessionGroupView`                             | None                      |
| LayoutResolved     | Rust `LayoutEngine`    | mode, width, status, session group count             | `LayoutPlan`                                   | None                      |
| ComponentRendered  | status components      | `RenderContext`, component cache                     | `RenderedSegment`, component cache             | component-scoped cache writes |
| RowsComposed       | Rust `StatusComposer`  | `LayoutPlan`, ordered `RenderedSegment` values       | `RenderedStatus`                               | None                      |
| CacheCommitted     | Rust `TmuxCacheStore`  | current cache, `RenderedStatus`, `LayoutPlan`        | tmux options and status settings               | batched tmux write        |
| StatusDisplayed    | tmux renderer          | cached options, native window formats                | terminal status area                           | status redraw             |

### Transitions

| From               | To                 | Trigger                         | Guard                              | On Failure                         |
|--------------------|--------------------|---------------------------------|------------------------------------|------------------------------------|
| EventReceived      | SnapshotCollected  | `ghc-tmux-status apply`         | binary executable                  | keep existing shell/status cache   |
| SnapshotCollected  | GroupResolved      | snapshot read succeeds          | current session name is available  | degrade to all non-special sessions |
| GroupResolved      | LayoutResolved     | group view built                | mode is `02` or `12`               | no-op for non-status02 modes       |
| LayoutResolved     | ComponentRendered  | layout plan selected            | status is not session-local `off`  | preserve existing status settings  |
| ComponentRendered  | RowsComposed       | required components returned    | `literal_text` and `rich_text` valid | omit optional failed components   |
| RowsComposed       | CacheCommitted     | render output complete          | output differs from current cache  | keep previous cache                |
| CacheCommitted     | StatusDisplayed    | tmux accepts batched writes     | tmux server reachable              | keep previous visible status       |
| RowsComposed       | StatusDisplayed    | output equals current cache     | no changes needed                  | no-op                              |

## 4. Failure Path

- retry: Hooks can re-run on the next resize, session switch, session create, session close, session rename, status interval, or manual theme reload.
- rollback: Disable the Rust hook path and source the existing shell-backed status02 config.
- degrade: If width is invalid, use wide layout; if session list read fails, render no session list and keep one row; if an optional component fails, omit it.
- abort: If tmux rejects the batched write or the Rust binary exits non-zero before commit, leave the previous tmux cache untouched where possible.

## 5. Invariants

- Rust never owns native window item rendering in this phase.
- Modes other than `02` and `12` are not modified by the Rust status02 path.
- Session-local `status off` prevents layout/status writes for that session context.
- A single-session current group renders its session list item and uses one status row.
- Multi-session current group uses two rows only when width is below `200`.
- Every component render returns `literal_text` and `rich_text`.
- `literal_text` contains no tmux style directives and is safe for monospace width calculation.
- `rich_text` is a tmux statusline format fragment and is never used for width calculation.
- Component cache writes are component-scoped; final status cache writes are renderer-scoped.
- Final cache commits are idempotent: identical target output results in no tmux write.

## 6. Test Matrix

| Case                  | Input                                  | Expected                                      |
|-----------------------|----------------------------------------|-----------------------------------------------|
| Single session group  | mode `02`, count `1`, width `120`      | one row with session list                     |
| Narrow group top      | mode `02`, count `2`, width `120`      | status `2`, top position, two cached rows     |
| Wide group top        | mode `02`, count `2`, width `220`      | status `on`, top position, one-line cache     |
| Narrow group bottom   | mode `12`, count `2`, width `120`      | status `2`, bottom position                   |
| Session-local off     | local `status off`                     | no status/layout writes                       |
| Component width       | component returns styled `rich_text`   | width uses only `literal_text`                |
| Component stale cache | component cache is fresh               | component skips expensive refresh             |
| Unknown mode          | mode `01` or invalid status02 context  | no-op                                         |
| Session group special | `_popup@*`, agent sessions, `G1-*`     | same grouping as current shell implementation |
| Renderer failure      | tmux read/write command fails          | previous visible status remains               |

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
