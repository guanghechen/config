# Session Last Focus Implementation Plan

## 1. Scope Mapping

| Design Ref | Design Source | Code Target | Test Target |
|------------|---------------|-------------|-------------|
| Snapshot last session | flow §3 | `model.rs`, `tmux.rs` | tmux parser tests |
| Render marker | flow §5 | `widget/session_list.rs` | session list render tests |
| Shortcut | flow §3 | keymap conf | `tmux source-file -n` |
| Theme color | arch §1 | `tmux.hbs` | diff review |

## 2. Work Breakdown

| Step | Design Ref | Change Area | Inputs | Outputs | Verification | Code Target |
|------|------------|-------------|--------|---------|--------------|-------------|
| 1 | Snapshot last session | Rust model/tmux | `client_last_session` | `TmuxSnapshot.client_last_session` | parser tests | `model.rs`, `tmux.rs` |
| 2 | Render marker | session list | group + last session | orange text for last item | render tests | `widget/session_list.rs` |
| 3 | Shortcut | keymaps | keypress | `switch-client -l` | `source-file -n` | `conf/keymap*.tmux.conf` |
| 4 | Validation | crate/conf | code tree | green checks | fmt/test/clippy/build/source-file | Rust + tmux conf |

## 3. Acceptance Criteria

- The visible last session item uses orange text unless it is the active session.
- The marker follows tmux `client_last_session` after session switches.
- `"` and `M-'"'` switch to the last session through tmux native behavior.
- Existing session order/focus/swap behavior remains unchanged.

## 4. Rollback Plan

Remove `client_last_session` from the snapshot, remove last-session palette logic, remove the new key bindings, and remove the theme token.

## 5. Progress

| Step | Status | Notes |
|------|--------|-------|
| 1 | completed | `client_last_session` is parsed from the tmux context snapshot. |
| 2 | completed | Visible inactive last session uses orange text. |
| 3 | completed | `"` and `M-'"'` bind to `switch-client -l`. |
| 4 | completed | Rust tests/clippy/build and tmux source-file dry-run passed. |
