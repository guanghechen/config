# Rust Status Renderer Implementation Plan

## 1. Scope Mapping

| Design Ref            | Design Source | Code Target                                      | Test Target                     |
|-----------------------|---------------|--------------------------------------------------|---------------------------------|
| CLI boundary          | arch.md       | `rust/ghc-tmux-status`                           | `cargo test`, CLI smoke tests   |
| tmux adapter          | arch.md       | Rust tmux command module                         | isolated tmux server tests      |
| component contract    | arch.md       | Rust component trait and `RenderedSegment` model  | unit tests and type checks      |
| component cache       | arch.md       | Rust component cache store                       | cache freshness tests           |
| session grouping      | flow.md       | Rust session grouper                             | unit tests for name patterns    |
| layout engine         | flow.md       | Rust layout module                               | unit tests for mode/count/width |
| status02 components   | arch.md       | built-in component implementations               | golden output tests             |
| row composer          | flow.md       | Rust status composer                             | width and rich text tests       |
| cache commit          | flow.md       | Rust cache store plus `script/load-theme.sh` path | isolated tmux server tests      |
| tmux config migration | arch.md       | `conf/theme/status02.tmux.conf`                  | tmux parse and live reload      |

## 2. Work Breakdown

| Step | Design Ref          | Change Area              | Inputs                         | Outputs                         | Verification                        | Code Target                    |
|------|---------------------|--------------------------|--------------------------------|---------------------------------|-------------------------------------|--------------------------------|
| 1    | CLI boundary        | Rust scaffold            | repo conventions               | `ghc-tmux-status` binary crate   | `cargo test`                        | `rust/ghc-tmux-status`          |
| 2    | component contract  | pure Rust model          | `literal_text`, `rich_text` requirement | `RenderedSegment`, component trait | unit tests and compile checks | Rust component module           |
| 3    | component cache     | cache abstraction        | component ids and cache keys   | scoped component cache port      | freshness and stale fallback tests  | Rust cache module               |
| 4    | session grouping    | pure Rust logic          | current shell grouping rules   | `SessionGroupView`              | unit tests                          | Rust grouper module             |
| 5    | layout engine       | pure Rust logic          | mode, width, group count       | `LayoutPlan`                    | unit tests                          | Rust layout module              |
| 6    | tmux adapter        | tmux command wrapper     | live tmux formats/options      | `TmuxSnapshot`, current cache   | isolated tmux server test           | Rust tmux module                |
| 7    | status02 components | component renderer       | context, theme, component cache | component `RenderedSegment`s     | golden output tests                 | Rust component implementations  |
| 8    | row composer        | final row composition    | ordered component outputs      | rendered status02 cache strings | width calculation tests             | Rust composer module            |
| 9    | cache commit        | tmux write path          | rendered output and cache      | batched tmux option updates     | no-op diff test; isolated tmux test | Rust final cache module         |
| 10   | loader wiring       | tmux shell glue          | mode `02/12`, binary path      | Rust apply hook with fallback   | `bash -n`; tmux source validation   | `script/load-theme.sh`          |
| 11   | status02 config     | tmux format cache reads  | cached options                 | fewer `#(...)` shell calls      | visual check and diff comparison    | `conf/theme/status02.tmux.conf` |
| 12   | cleanup             | shell fallback decision  | verified Rust parity           | remove or retain shell helpers  | rollback check                      | `script/session-status.sh`      |

## 3. Acceptance Criteria

- Rust CLI can render status02 without rewriting native window item formats.
- Every component render returns `RenderedSegment { literal_text, rich_text }`.
- Renderer uses `literal_text` for monospace width calculation and `rich_text` for tmux status composition.
- Components own refresh decisions and component-scoped cache keys.
- Session group output matches the current shell implementation for normal, `_popup@*`, agent, and `G<number>-*` sessions.
- Single-session groups render their session list item and force one-row status.
- Multi-session groups use two rows only below width `200`.
- Session-local `status off` is preserved.
- Hook path avoids steady-state `#(bash session-status.sh ...)` for session list rendering after migration.
- No-op render path avoids tmux writes when final cache already matches.
- Existing shell-backed behavior remains available as rollback during phase 1.

## 4. Rollback Plan

- Keep existing shell scripts until Rust parity is verified.
- Gate Rust usage behind a tmux option such as `@GHC_STATUS_RENDERER=rust` or a loader-side binary existence check.
- To rollback, switch renderer option to shell or remove the Rust hook command and reload theme.
- Revert `conf/theme/status02.tmux.conf` cache-read changes if the generated cache contract changes unexpectedly.

## 5. Progress

| Step | Status  | Notes                                      |
|------|---------|--------------------------------------------|
| 1    | done    | Added no-dependency Rust CLI crate         |
| 2    | done    | Added `RenderedSegment` and component trait |
| 3    | done    | Added tmux option-backed component cache MVP |
| 4    | done    | Ported shell grouping semantics with tests |
| 5    | done    | Added adaptive layout engine with tests    |
| 6    | done    | Added live tmux snapshot and batched commit |
| 7    | done    | Added status02 built-in component MVP      |
| 8    | done    | Added width calculation from `literal_text` |
| 9    | done    | Added final cache diff before commit       |
| 10   | done    | `load-theme.sh` uses release binary with shell fallback |
| 11   | pending | Visual verification required before switch |
| 12   | pending | Cleanup only after parity                  |
