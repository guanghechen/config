# Status Right Dynamic Length Implementation Plan

## 1. Scope Mapping

| Design Ref | Design Source | Code Target | Test Target |
|------------|---------------|-------------|-------------|
| faithful right literal | arch.md widgets | `src/widget/*.rs`, `src/widget/pill.rs` | widget unit tests |
| dynamic right length | flow.md LengthComputed | `src/status_length.rs` | status_length tests |
| commit/no-op path | flow.md LengthCommitted | `src/commit.rs`, `src/composer.rs`, `src/tmux.rs` | commit/composer tests |

## 2. Work Breakdown

| Step | Design Ref | Change Area | Inputs | Outputs | Verification | Code Target |
|------|------------|-------------|--------|---------|--------------|-------------|
| 1 | faithful right literal | widget render | widget body literal | pill-aware literal | cargo test | `src/widget` |
| 2 | dynamic right length | length computation | rendered right literal | `status-right-length` | cargo test | `src/status_length.rs` |
| 3 | runtime option path | commit/cache/snapshot | tmux snapshot + computed length | convergent no-op | cargo test | `src/{commit,composer,tmux}.rs` |
| 4 | live validation | release binary | fullscreen status02 | seconds not clipped | render/apply smoke | release build |

## 3. Acceptance Criteria

- `status-right-length` is dynamically committed from faithful/pessimistic right literal width.
- Fullscreen/prefix conditional widgets cannot make right length underestimate.
- `cargo test`, `cargo clippy -- -D warnings`, and release render/apply smoke pass.

## 4. Rollback Plan

- Remove `status-right-length` from runtime snapshot/cache/commit checks.
- Revert right widget literal placeholders to previous body-only literals.
- Keep theme static `84` as fallback.

## 5. Progress

| Step | Status | Notes |
|------|--------|-------|
| 1 | completed | Right-side pill literals include round/icon placeholders and pessimistic conditional width. |
| 2 | completed | `status_right_length` mirrors left dynamic formula with static floor 84. |
| 3 | completed | Snapshot/cache/commit now include `status-right-length`. |
| 4 | completed | Cargo tests, clippy, release build, and live apply smoke passed. |
