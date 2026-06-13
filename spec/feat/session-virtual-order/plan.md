# Session Virtual Order Implementation Plan

## 1. Scope Mapping

| Design Ref | Design Source | Code Target | Test Target |
|------------|---------------|-------------|-------------|
| session order pure logic | flow.md OrderedSessions/SwappedOrder | `src/session/list.rs` | unit tests |
| render parity | flow.md OrderedSessions | `runtime.rs`, `widget/session_list.rs` | render smoke |
| focus/swap CLI | arch.md Runtime/TmuxAdapter | `main.rs`, `app.rs`, `runtime.rs`, `tmux.rs` | unit + manual smoke |
| key bindings | arch.md scripts/keymap | `script/focus-session.sh`, `conf/keymap*.tmux.conf` | shell syntax check |

## 2. Work Breakdown

| Step | Design Ref | Change Area | Inputs | Outputs | Verification | Code Target |
|------|------------|-------------|--------|---------|--------------|-------------|
| 1 | session order pure logic | session module | sessions/order/current | ordered list/swap/focus | cargo test | `src/session` |
| 2 | render parity | runtime snapshot ordering | `@GHC_SL_SESSION_ORDER` | ordered status list | render status02 | `tmux.rs`, `runtime.rs` |
| 3 | CLI side effects | session commands | focus/swap args | switch/order write | cargo test/clippy | `main.rs`, `runtime.rs`, `tmux.rs` |
| 4 | key bindings | shell/tmux conf | user key press | focus script or direct Rust swap command | bash -n / source-file -n | `script`, `conf` |

## 3. Acceptance Criteria

- Rendered session list and `session focus 1..9/prev/next` share the same order.
- `session swap prev|next` swaps current session with visible neighbor in current group only, wrapping first/last like focus shortcuts.
- A single visible session swap is no-op with a tmux message.
- Stale ids are ignored; new ids append.
- `cargo test`, `cargo clippy -- -D warnings`, and `bash -n` pass.

## 4. Rollback Plan

- Remove key bindings and scripts.
- Remove `@GHC_SL_SESSION_ORDER` from snapshot options.
- Revert runtime ordering to raw `SessionGrouper::group`.

## 5. Progress

| Step | Status | Notes |
|------|--------|-------|
| 1 | completed | Pure order/focus/swap logic covered by unit tests. |
| 2 | completed | Runtime applies virtual order before render/focus/swap. |
| 3 | completed | CLI delegates to runtime and tmux adapter side effects. |
| 4 | completed | Keymaps and focus script validated with syntax checks. |
