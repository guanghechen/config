# Session Last Focus Draft

## 1. Problem Statement

status02 should mark the previously focused session item, and a shortcut should switch back to that session. The desired behavior is similar to tmux `last-window`: highlight the previously visited item and jump back quickly.

## 2. Context and Constraints

- tmux already maintains `client.last_session` and exposes it as `#{client_last_session}`.
- `switch-client -l` already implements the jump-to-last-session behavior.
- status02 is rendered into global tmux status options by Rust, so per-client state is best-effort in multi-client setups, matching existing client-width/current-client assumptions.
- The session list style is sensitive; this feature only changes text foreground for the last session item.

## 3. Open Questions

| Question | Options | Decision | Rationale |
|----------|---------|----------|-----------|
| State owner | Rust option stack / tmux `client_last_session` | tmux `client_last_session` | Reuses tmux's per-client source of truth and avoids duplicate state. |
| Jump action | Rust CLI / `switch-client -l` | `switch-client -l` | Native tmux behavior is already correct and per-client. |
| Visual treatment | background change / text foreground only | text foreground only | User requested orange text; avoids slant/background churn. |

## 4. Risk Notes

| Risk | Trigger | Evidence | Impact | Mitigation |
|------|---------|----------|--------|------------|
| Multi-client mismatch | multiple clients render different `client_last_session` into global status options | status options are global | one client may see another client's last marker | Accept current runtime model; no new global state. |
| Invisible last session | last session outside current group | grouped session list filters sessions | no marker visible | Treat as expected; shortcut still works through tmux. |
| Key delivery | terminal may not send Cmd+Shift+`"` as tmux `M-'"'` | terminal-specific | binding may not fire | Bind tmux-level `M-'"'`; terminal mapping can be adjusted separately. |

## 5. Draft Decisions

- Add `client_last_session` to `TmuxSnapshot` from the context snapshot line.
- Mark `client_last_session` only when it is visible and not the active session.
- Use `@GHC_SL_FG_SESSION_ITEM_LAST` for last-session text foreground.
- Bind prefix `"` and Meta/Command `M-'"'` to `switch-client -l`.
