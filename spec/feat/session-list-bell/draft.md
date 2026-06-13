# Session List Bell Draft

## 1. Problem Statement

status02 should show which visible session has a bell. A session is considered belling when any window in that session has `window_bell_flag`; the runtime computes this by aggregating `window_bell_flag` over windows with the same `session_id`. When the bell window is focused, tmux clears the window alert and the session bell state must disappear on the next runtime refresh.

## 2. Context and Constraints

- status02 session list is rendered by Rust and committed as tmux status text.
- The runtime already runs a one-second `apply tick`; this is sufficient to re-detect bell clear/set without adding hooks.
- Session item slants and inactive colors are visually sensitive; this feature must not change item edges or base palettes.
- `#[range=session|...]` is mouse metadata and must not be used as the data source for per-session format evaluation.

## 3. Open Questions

| Question | Options | Decision | Rationale |
|----------|---------|----------|-----------|
| Bell source | `session_bell_flag` / aggregate `window_bell_flag` by `session_id` | aggregate window bell | `session_bell_flag` can be false while a non-active window in the same session still has `window_bell_flag=1`. |
| Visual treatment | recolor whole item / add local icon | add local icon | Minimal style impact; slants remain unchanged. |
| Refresh trigger | window hooks / existing tick | existing tick | Bell clears on focus and tick re-reads snapshot within 1s. |

## 4. Risk Notes

| Risk | Trigger | Evidence | Impact | Mitigation |
|------|---------|----------|--------|------------|
| Bell state stale | bell set/cleared between commits | Rust status text is pre-rendered | Icon may lag | Existing one-second tick recomputes snapshot and commits changed text. |
| Visual regression | changing slants or base backgrounds | session list style is sensitive | Color/edge mismatch | Only insert icon inside item body. |
| Parser drift | snapshot format changes | sessions currently parse id/name | broken grouping/focus | Add backward-compatible parser tests for bell field. |

## 5. Draft Decisions

- Extend `SessionInfo` with `has_bell: bool`.
- Read sessions from `tmux list-sessions -F` and aggregate bell state from `tmux list-windows -a -F "#{session_id}\t#{window_bell_flag}"`.
- Render `@GHC_SYM_WIN_BELL` after the session number when `has_bell` is true.
- Keep session ordering, grouping, focus, swap, and slant boundary logic unchanged.
