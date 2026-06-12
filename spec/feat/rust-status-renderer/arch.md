# Rust Status Renderer Architecture Spec

## 1. Module Boundary (SRP)

| Module                         | Responsibility                                  | Public Ports                                      | Private Runtime                         |
|--------------------------------|-------------------------------------------------|---------------------------------------------------|-----------------------------------------|
| tmux config                    | Define status modes, window formats, hook wiring | `source-file`, tmux hooks, tmux options           | tmux format strings                     |
| `script/load-theme.sh`         | Select legacy shell path or Rust status path     | `@GHC_SL_MODE`, hook registration                 | mode normalization                      |
| Rust CLI                       | Command boundary and process lifecycle           | `apply`, `render`, `layout`, `dump-state`         | argument parsing, exit codes            |
| `TmuxAdapter`                  | Execute tmux reads/writes                        | `read_snapshot`, `read_cache`, `commit_batch`     | command construction, escaping          |
| `SessionGrouper`               | Resolve current session group                    | `group(current, sessions)`                        | grouping predicates                     |
| `LayoutEngine`                 | Select row count and position                    | `resolve(snapshot, group)`                        | threshold and mode rules                |
| `StatusComponent`             | Render one autonomous status component           | `render(context, cache)`                          | component refresh and cache policy      |
| `ComponentRegistry`            | Provide ordered components for a layout slot      | `components(slot)`                                | built-in component map                  |
| `ComponentCacheStore`          | Provide scoped cache access to components         | `read_component`, `write_component`               | cache key namespace and serialization   |
| `StatusComposer`               | Compose component outputs into status rows        | `compose(layout, segments)`                       | tmux style string builder and width calc |
| `TmuxCacheStore`               | Own final cached tmux option writes               | `diff`, `commit`, `refresh`                       | option names and batched write ordering |
| optional component plugin      | Extend components without changing core           | component plugin contract                         | isolated render implementation          |

## 2. Dependency Graph

- one-way dependencies:
  - tmux hooks -> Rust CLI -> application service.
  - application service -> `TmuxAdapter`, `SessionGrouper`, `LayoutEngine`, `ComponentRegistry`, `StatusComposer`, `TmuxCacheStore`.
  - `ComponentRegistry` -> built-in `StatusComponent` implementations or optional component plugins.
  - `StatusComponent` -> `ComponentCacheStore` interface only.
  - `StatusComposer` -> `RenderedSegment` values only.
  - tmux final renderer -> cached tmux options and native window formats.
- forbidden reverse dependencies:
  - Components must not call `TmuxAdapter` directly.
  - Components must not mutate final status cache directly.
  - `StatusComposer` must not access component internal cache.
  - `SessionGrouper` must not write tmux options.
  - `LayoutEngine` must not read tmux state directly.
  - tmux config must not depend on Rust internal module names.
  - Optional plugins must not mutate core cache or tmux state directly.

## 3. Interaction Lifecycle Model

### Lifecycle

- init:
  - tmux sources theme files and registers hooks.
  - Rust CLI loads built-in component registry for each invocation.
  - Optional components are loaded behind the same registry interface when enabled later.
- start:
  - tmux invokes `ghc-tmux-status apply` on load or hook events.
  - Rust collects a snapshot, builds a render context, invokes components, composes target rows, and commits changed options.
- stop:
  - Switching away from mode `02` or `12` disables the Rust status02 hook path and restores the selected status mode behavior.
- dispose:
  - CLI process exits after each command.
  - No daemon state is required in phase 1.
  - tmux options remain as observable cache until overwritten or unset.

### Interaction Transitions

| From        | To          | Event                   | Guard                         | Timeout          | Error Handling                       |
|-------------|-------------|-------------------------|-------------------------------|------------------|--------------------------------------|
| init        | start       | theme load              | mode is `02` or `12`          | soft `100ms`     | fall back to existing cache/status   |
| start       | start       | resize/session hook     | status is not local `off`     | soft `100ms`     | no-op on collector failure           |
| start       | start       | component render        | component registered          | component budget | use stale component cache or omit optional component |
| start       | stop        | mode changed            | mode not `02` or `12`         | soft `100ms`     | shell loader overwrites status       |
| start       | dispose     | CLI command completed   | render or no-op completed     | immediate        | non-zero exit with stderr reason     |
| start       | start       | optional plugin failure | plugin render returns error   | component budget | omit component and continue          |

## 4. Interface Contracts

| Port                   | Input                                      | Output                                  | Idempotency        | Timeout          | Error Contract                       |
|------------------------|--------------------------------------------|-----------------------------------------|--------------------|------------------|--------------------------------------|
| `apply`                | optional target session/client context     | tmux cache/status writes                | idempotent         | soft `100ms`     | non-zero exit; previous cache remains |
| `render status02`      | snapshot JSON or live tmux context         | rendered status strings                 | pure with snapshot | soft `50ms`      | structured error on invalid input    |
| `layout`               | mode, width, group count, status           | layout plan                             | pure               | soft `10ms`      | invalid width degrades to wide       |
| `dump-state`           | live tmux context                          | debug JSON                              | read-only          | soft `100ms`     | non-zero exit on tmux read failure   |
| `read_snapshot`        | tmux context                               | `TmuxSnapshot`                          | read-only          | soft `50ms`      | wrapped tmux command error           |
| `component.render`     | `RenderContext`, scoped component cache    | `RenderedSegment`                       | component-defined  | component budget | stale cache, empty segment, or typed error |
| `compose`              | `LayoutPlan`, ordered `RenderedSegment`    | `RenderedStatus`                        | pure               | soft `10ms`      | typed error on invalid segment       |
| `commit_batch`         | option diff and status settings            | tmux server state                       | idempotent         | soft `50ms`      | atomic-like batch; report failed cmd |
| plugin load            | manifest and compatibility info            | registered component capabilities       | repeatable         | soft `20ms`      | disable plugin with warning          |

### Core Data Contracts

```rust
pub struct RenderedSegment {
    pub literal_text: String,
    pub rich_text: String,
}

pub struct RenderContext {
    pub snapshot: TmuxSnapshot,
    pub group: SessionGroupView,
    pub layout: LayoutPlan,
    pub theme: ThemeValues,
}

pub trait StatusComponent {
    fn id(&self) -> ComponentId;
    fn render(&mut self, context: &RenderContext, cache: &mut dyn ComponentCache) -> Result<RenderedSegment, ComponentError>;
}
```

- `literal_text` is plain display text and must exclude tmux style directives.
- `rich_text` is a tmux statusline fragment and may contain styles, ranges, conditionals, and tmux formats.
- Component cache keys are scoped by component id.
- Components decide whether cached data is fresh enough for their own semantics.
- The renderer uses `literal_text` for width calculation and `rich_text` for final composition.

## 5. Minimal Core + Plugin Contract

### Minimal Core

- baseline capabilities:
  - collect current tmux mode, status, width, current session, and session list.
  - resolve the same session groups as the current shell implementation.
  - render status02 through built-in components: session list, host, prefix indicator, duration/date/time placeholders, fullscreen indicator, and window-id component.
  - keep native window list formats untouched.
  - compose rows from `RenderedSegment` objects.
  - write cached tmux options and adaptive row settings.
- works without optional plugins: true

### Plugin Contract

- manifest fields:
  - `name`
  - `version`
  - `capabilities`
  - `compatibility.core_api`
  - `compatibility.tmux_min_version`
- lifecycle hooks:
  - `onLoad(manifest, core_api)` validates compatibility and returns capabilities.
  - `onStart(context)` prepares plugin-local state for the current render.
  - `onStop()` releases per-render resources.
  - `onUnload()` releases loaded resources.
- render contract:
  - plugins implement the same component render contract as built-in components.
  - plugins receive immutable `RenderContext` and scoped cache access.
  - plugins return `RenderedSegment` or a typed error.
  - plugins cannot call tmux directly through core internals.
- failure isolation:
  - timeout guard per component.
  - circuit breaker disables repeated failing optional plugins for the current invocation.
  - safe fallback uses stale component cache or omits the optional component while core components continue rendering.

## 6. Observability and Degrade Strategy

- Observability:
  - `ghc-tmux-status dump-state` prints snapshot, resolved group, layout plan, component cache state, component outputs, and final cache diff.
  - `@GHC_SL_LAYOUT` records current mode/layout key.
  - Rendered cache options are named with a stable `@GHC_STATUS_*` or `@GHC_SL_*` prefix.
  - Component cache options include the component id in the key.
  - Non-zero CLI exits include a concise stderr reason.
- Degrade:
  - invalid width -> wide layout.
  - session list read failure -> no session list and one-row status.
  - component refresh failure with stale cache -> return stale `RenderedSegment`.
  - component refresh failure without stale cache -> return empty segment for optional components or abort required component render.
  - Rust binary missing -> retain shell-backed status02 path until migration completes.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
