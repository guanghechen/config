# Session Last Focus Flow Spec

## 1. Scope

Highlight the previously focused session in status02 and add a shortcut to jump to it.

## 2. Boundary

- Input Boundary: tmux context format `#{client_last_session}`, current session name, grouped session list, and keypress `"` / `M-'"'`.
- Output Boundary: committed session list rich text and tmux `switch-client -l` action.

## 3. Dataflow State Machine

### States

| State             | Owner                 | Read Set                         | Write Set              | Side Effects             |
|-------------------|-----------------------|----------------------------------|------------------------|--------------------------|
| LastSessionState  | tmux client           | client session switch history    | `client_last_session`  | updated by tmux          |
| SnapshotLoaded    | `TmuxAdapter`         | tmux context + sessions/windows  | `TmuxSnapshot`         | tmux subprocess          |
| RenderedList      | `SessionListWidget`   | group sessions + last session    | `RenderedSegment`      | none                     |
| Committed         | `CommitPlanner`       | rendered text + current options  | tmux status options    | tmux `set`/refresh       |
| LastSessionJumped | tmux key binding      | `client.last_session`            | client current session | `switch-client -l`       |

### Transitions

| From             | To                | Trigger                  | Guard                            | On Failure          |
|------------------|-------------------|--------------------------|----------------------------------|---------------------|
| LastSessionState | SnapshotLoaded    | tick/session/manual apply | status02 active                 | retry next apply    |
| SnapshotLoaded   | RenderedList      | render status02          | visible session count > 1        | render empty on <=1 |
| RenderedList     | Committed         | cache mismatch           | rendered text changed            | keep prior status   |
| LastSessionState | LastSessionJumped | keypress                 | tmux has live last session       | tmux message/error  |

## 4. Failure Path

- retry: render state retries on next tick/session hook/manual apply.
- rollback: failed commit leaves previous status options intact.
- degrade: missing `client_last_session` renders no last marker.
- abort: invalid snapshot boundary aborts current apply.

## 5. Invariants

- Active session styling has higher priority than last-session styling.
- Last-session marker is visible only when the last session is in the rendered group.
- Rendering last-session state does not mutate session order or focus state.
- Jump shortcut delegates to tmux `switch-client -l`.

## 6. Test Matrix

| Case | Expected |
|------|----------|
| snapshot context has `client_last_session` | `TmuxSnapshot.client_last_session` is populated |
| visible inactive last session | item text uses `@GHC_SL_FG_SESSION_ITEM_LAST` |
| current session equals last session | active styling wins; no last styling |
| no last session | existing inactive styling remains |
| keymap syntax | `tmux source-file -n` accepts both keymap files |

## 7. Open Decisions（唯一待定区）

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
