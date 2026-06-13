# Session List Bell Implementation Plan

## 1. Scope Mapping

| Design Ref | Design Source | Code Target | Test Target |
|------------|---------------|-------------|-------------|
| Bell snapshot | flow §3 | `tmux.rs`, `model.rs` | tmux session/window parser tests |
| Bell render | flow §5 | `widget/session_list.rs` | session list render tests |
| Convergence | flow §3/§4 | existing runtime tick | no new runtime code |

## 2. Work Breakdown

| Step | Design Ref | Change Area | Inputs | Outputs | Verification | Code Target |
|------|------------|-------------|--------|---------|--------------|-------------|
| 1 | Bell snapshot | model/tmux | `window_bell_flag` grouped by `session_id` | `SessionInfo.has_bell` | parser tests | `model.rs`, `tmux.rs` |
| 2 | Bell render | widget | session `has_bell` | icon in item body | render tests | `widget/session_list.rs` |
| 3 | Validation | tests/build | code tree | green checks | fmt/test/clippy/build | Rust crate |

## 3. Acceptance Criteria

- A session item shows bell when any window in that session has bell.
- Focusing the alerted window clears the marker after the next tick.
- Existing session ordering/focus/swap behavior is unchanged.
- Session list slant boundaries and inactive no-`|` style remain unchanged.

## 4. Rollback Plan

Revert `SessionInfo.has_bell`, restore two-field `list-sessions` format, and remove bell marker rendering. Existing status02 behavior returns unchanged.

## 5. Progress

| Step | Status | Notes |
|------|--------|-------|
| 1 | completed | `SessionInfo.has_bell` is computed by aggregating `window_bell_flag` per `session_id`. |
| 2 | completed | Session items render a local bell icon without changing slants. |
| 3 | completed | `cargo fmt`, `cargo test`, `cargo clippy -- -D warnings`, and release build passed. |
