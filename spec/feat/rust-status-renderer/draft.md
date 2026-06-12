# Rust Status Renderer Draft

## 1. Problem Statement

The current tmux statusline has grown from small shell helpers into a layout and rendering system. The hot paths now include session grouping, adaptive row selection, status component rendering, and cache-like option updates. Shell remains useful as glue, but it is becoming hard to reason about correctness, performance, and future extensibility.

The target direction is a Rust CLI-first renderer with a first-class component model. Each component owns its refresh policy and cache semantics, returns both display text and tmux rich format, and lets the renderer compose final statusline rows without knowing component internals.

## 2. Context and Constraints

- Keep tmux native `window-status-format`, `window-status-current-format`, and `#{W:...}` window list rendering. Window item visual behavior is already good and is out of scope.
- Replace shell hot paths gradually. Existing shell remains the rollback path until Rust reaches parity.
- Preserve status modes `01`, `02`, `11`, and `12`; adaptive behavior stays under `02` and `12`.
- Preserve the current status02 rule: one session in the current group uses one row regardless of width; multiple sessions use one row at width `>=200` and two rows below `200`.
- Preserve session grouping semantics currently implemented by `_ghc_tmux_same_session_group_`.
- Avoid `#(...)` commands inside steady-state statusline where possible. Prefer cached tmux options rendered by Rust and read by `#{E:@...}`.
- Component rendering returns an object with `literal_text` and `rich_text`.
- `literal_text` is the display-only plain text used for monospace width calculation.
- `rich_text` is the tmux statusline format fragment used for final composition.
- Components own their cache keys, refresh conditions, and stale/degrade behavior. The core provides cache access ports but does not own component cache policy.
- Theme colors and symbols continue to come from generated tmux options. If new variables are needed, define them in `/Users/wanchenfang/.config/guanghechen/asset/theme/app/tmux.hbs` and generate with `fish -c "ghc-theme gen && ghc-theme apply"`.
- Initial delivery is CLI-first, not daemon-first. A daemon can be added after the data model and cache contract are stable.

## 3. Candidate Approaches

| Approach                 | Example                                                | Strength                                  | Weakness                                  | Decision    |
|--------------------------|--------------------------------------------------------|-------------------------------------------|-------------------------------------------|-------------|
| Pure tmux format         | Encode session list with `#{}` and hooks               | No extra binary                           | Hard to test; hard cache ownership        | Reject      |
| Rust CLI with components | Hook runs `ghc-tmux-status apply`; components render segments | Clear ownership; testable; cacheable      | One process spawn per hook                | Accept      |
| Rust daemon              | tmux hook sends event to daemon socket                 | Best long-run cache and event handling    | More lifecycle failure modes              | Later phase |

## 4. Component Model Examples

| Component        | Cache Owner              | Refresh Trigger                         | `literal_text` Example | `rich_text` Example                                      |
|------------------|--------------------------|-----------------------------------------|------------------------|----------------------------------------------------------|
| session list     | `SessionListComponent`   | session create/close/rename/change      | ` yui | 1  tmux | 2 ` | `#[fg=...,bg=...] yui | 1 #[default] ...`             |
| duration         | `DurationComponent`      | elapsed minute boundary or stale cache  | ` 2h13m `              | `#[fg=...,bg=...]󰔚 #[default] 2h13m `                   |
| host             | `HostComponent`          | hostname/theme changes                  | ` MacBook-Pro `        | `#[fg=...,bg=...] #[default] MacBook-Pro `             |

The renderer uses `literal_text` to calculate widths and truncation decisions. It uses `rich_text` only when building the final tmux format string.

## 5. Open Questions

| Question             | Options                                      | Decision                  | Rationale                                  |
|----------------------|----------------------------------------------|---------------------------|--------------------------------------------|
| Language             | Bash / Go / Rust                             | Rust                      | Strong state model and long-term engine fit |
| Integration style    | Pure tmux / CLI cache / daemon               | CLI cache first           | Lowest risk migration with clear rollback  |
| Window list owner    | tmux native / Rust renderer                  | tmux native               | Existing window item is already good       |
| Component output     | string only / `literal_text` + `rich_text`   | object output             | Enables width calculation and rich tmux composition |
| Cache owner          | renderer / component / daemon memory         | component                 | Keeps refresh policy near data ownership   |
| First migration area | status01 / status02 / all modes              | status02 first            | Current complexity is concentrated there   |
| Binary location      | repo-local target / `~/.local/bin` / plugin dir | repo-local with optional wrapper | Avoid global install requirement during development |

## 6. Risk Notes

| Risk                         | Trigger                                 | Evidence                            | Impact                                | Mitigation                               |
|------------------------------|-----------------------------------------|-------------------------------------|---------------------------------------|------------------------------------------|
| Hook spawn overhead          | Resize/session events happen frequently | CLI process starts per hook         | Status update latency                 | Component cache no-op path; single batch write |
| Cache ownership fragmentation | Every component owns refresh policy     | Multiple cache keys and stale rules | Harder debug                          | Stable cache namespace and `dump-state`  |
| tmux command fan-out         | Components independently read tmux       | Component autonomy can duplicate reads | More server round trips             | Shared immutable snapshot plus component-local cache |
| Partial cache update         | Renderer fails after some writes         | tmux option writes are side effects | Inconsistent status pieces            | Render all component outputs before one batched commit |
| Visual regression            | Rust-generated format differs from shell | Statusline is glyph/color sensitive | Ugly or broken statusline             | Keep shell fallback and compare option output |
| Overbuilt plugin system      | Too much dynamic loading too early       | Initial needs are built-in components | Slower delivery                       | Define plugin contract; implement built-in registry first |

## 7. Draft Decisions

- Build a Rust CLI named `ghc-tmux-status`.
- Keep tmux as the status renderer and hook/event source.
- Rust owns orchestration, layout selection, final composition, and cache commit.
- Components own component-specific cache policy and return `RenderedSegment { literal_text, rich_text }`.
- Components receive a shared immutable `RenderContext` and a scoped cache port.
- Renderer composes rows from component outputs; it should not inspect component internals.
- Statusline config should read cached options with `#{E:@...}` instead of running shell renderers on every refresh.
- Rust should batch tmux writes and skip commits when the final target cache is unchanged.
- The first implementation should be runnable without any optional plugin.
- Optional component plugins are designed as a stable interface, but the first phase uses compiled-in components only.
