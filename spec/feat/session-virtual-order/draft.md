# Session Virtual Order Draft

## 1. Problem Statement

status02 session list follows `tmux list-sessions` order. The user wants shortcuts to swap the current session with its visible previous/next session, and expects focus shortcuts and rendered indices to follow the same order.

## 2. Context and Constraints

- tmux has no native `swap-session` command.
- Session display is grouped: normal, popup, agent, and `G<n>-*` sessions are separate visible groups.
- Existing status click ranges use `session_id`; ordering should also use stable `session_id`, not session names.
- External tmux state is acceptable for ordering because the order must survive process exits.

## 3. Open Questions

| Question | Options | Decision | Rationale |
|----------|---------|----------|-----------|
| Persistence key | global option / file | global option `@GHC_SL_SESSION_ORDER` | Simple, tmux-native, no filesystem state. |
| Order identity | name / id | session id | Stable across rename. |
| Move boundary | wrap / no-op | no-op at boundary | Reordering is editing; wrap is surprising. |
| Focus parity | leave shell order / share virtual order | share virtual order | Rendered numbers and focus shortcuts must match. |

## 4. Risk Notes

| Risk | Trigger | Evidence | Impact | Mitigation |
|------|---------|----------|--------|------------|
| Stale ids | Session closed | Option persists ids | Wrong order if not pruned | Ignore stale ids during render; prune on swap. |
| New ids missing | New session created | Option predates session | New session invisible/orderless | Append unknown live ids after known ordered ids. |
| Script fallback mismatch | Rust binary missing | keymap uses script | Focus may use native order | Keep fallback only for binary-missing degrade; normal path Rust-owned. |

## 5. Draft Decisions

Implement a Rust-owned session domain module:

- `src/session/group.rs`: existing grouping rules.
- `src/session/item.rs`: command value types and typed swap outcomes.
- `src/session/list.rs`: parse/apply/swap virtual order.
- `src/session/mod.rs`: public facade.

Runtime owns tmux side effects; session module stays pure.
