# Session Virtual Order Flow Spec

## 1. Scope

Add a virtual session order shared by status02 rendering and session focus/swap shortcuts.

## 2. Boundary

- Input Boundary: tmux snapshot sessions, current session name, `@GHC_SL_SESSION_ORDER`, user command `session focus|swap <target>`.
- Output Boundary: rendered status02 session list order, `tmux switch-client`, `tmux set -g @GHC_SL_SESSION_ORDER`, status refresh.

## 3. Dataflow State Machine

### States

| State | Owner | Read Set | Write Set | Side Effects |
|-------|-------|----------|-----------|--------------|
| SnapshotRead | TmuxAdapter | tmux sessions/options/current session | `TmuxSnapshot` | `tmux display-message/list-sessions` |
| GroupedSessions | session::group | `TmuxSnapshot.sessions/current_session_name` | `SessionGroupView` | none |
| OrderedSessions | session::list | group sessions + order option | ordered session list | none |
| FocusedSession | StatusRuntime | ordered group + focus target | target session id | `tmux switch-client` |
| SwappedOrder | StatusRuntime + session::list | live sessions + ordered group + direction | `@GHC_SL_SESSION_ORDER` | `tmux set -g`, status apply |

### Transitions

| From | To | Trigger | Guard | On Failure |
|------|----|---------|-------|------------|
| SnapshotRead | GroupedSessions | render/focus/swap | snapshot valid | abort with tmux parse error |
| GroupedSessions | OrderedSessions | render/focus/swap | order option parsed leniently | degrade by appending live sessions |
| OrderedSessions | FocusedSession | `session focus` | target exists | display message and no-op |
| OrderedSessions | SwappedOrder | `session swap` | visible sessions > 1 | wrap around and swap first/last visible sessions; no-op when alone |
| SwappedOrder | SnapshotRead | order written | status02 active or inactive | retry through normal runtime apply path |

## 4. Failure Path

- retry: none; commands are idempotent.
- rollback: old order remains if `tmux set -g` fails.
- degrade: missing/stale order ids are ignored; new sessions append.
- abort: tmux command failures propagate as `AppError`.

## 5. Invariants

- Render order and focus numeric order use the same ordered group.
- The persisted order stores session ids only.
- Reordering never crosses the current visible session group.
- Boundary swap wraps like focus shortcuts when visible session count > 1; a single visible session is no-op.

## 6. Test Matrix

- Apply order with stale ids and missing new ids.
- Swap current with previous/next.
- Swap at first/last returns boundary no-op.
- Focus by index and prev/next uses ordered group.

## 7. Open Decisions

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
