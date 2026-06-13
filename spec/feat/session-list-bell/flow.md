# Session List Bell Flow Spec

## 1. Scope

Add per-session bell indication to status02 session list. A session has bell when tmux reports `session_bell_flag=1`, i.e. any window in that session has bell.

## 2. Boundary

- Input Boundary: `tmux list-sessions -F "#{session_id}\t#{session_name}\t#{session_bell_flag}"` and existing one-second `apply tick`.
- Output Boundary: committed status02 session list rich text and literal width shadow.

## 3. Dataflow State Machine

### States

| State          | Owner             | Read Set                         | Write Set                | Side Effects        |
|----------------|-------------------|----------------------------------|--------------------------|---------------------|
| TmuxAlertState | tmux server       | window alert flags               | `session_bell_flag`      | clears on focus     |
| SnapshotLoaded | `TmuxAdapter`     | `list-sessions` output           | `TmuxSnapshot.sessions`  | tmux subprocess     |
| GroupOrdered   | `session` domain  | sessions + virtual order         | `SessionGroupView`       | none                |
| RenderedList   | `SessionListWidget` | ordered sessions + `has_bell`  | `RenderedSegment`        | none                |
| Committed      | `CommitPlanner`   | rendered text + current options  | tmux status options      | tmux `set`/refresh  |

### Transitions

| From           | To             | Trigger                         | Guard                    | On Failure               |
|----------------|----------------|---------------------------------|--------------------------|--------------------------|
| TmuxAlertState | SnapshotLoaded | tick/theme/session/manual apply | status02 active          | abort current apply      |
| SnapshotLoaded | GroupOrdered   | snapshot parsed                 | valid current session    | abort current apply      |
| GroupOrdered   | RenderedList   | render status02                 | visible sessions > 1     | render empty on <=1      |
| RenderedList   | Committed      | cache mismatch                  | text or length changed   | leave previous status    |
| Committed      | SnapshotLoaded | next tick                       | status02 active          | retry next tick          |

## 4. Failure Path

- retry: transient tmux read/commit failure retries on the next tick or manual apply.
- rollback: no rollback; previous committed status remains visible if commit fails.
- degrade: malformed/missing bell field is treated as `false` for backward compatibility.
- abort: invalid snapshot boundary aborts the current apply.

## 5. Invariants

- `has_bell=true` means tmux reported `session_bell_flag=1` for that session.
- Bell rendering must not change slant edge rules or item base palettes.
- `literal_text` must include one visible placeholder cell for each rendered bell icon.
- Bell clear after focusing the alerted window must converge through the existing one-second tick.

## 6. Test Matrix

| Case | Expected |
|------|----------|
| parse session with `session_bell_flag=1` | `SessionInfo.has_bell=true` |
| parse legacy two-field session line | `has_bell=false` |
| active item with bell | renders bell icon after number and accounts literal width |
| inactive item with bell | renders bell icon after number and keeps no `|` separator |
| no bell | existing session body shape remains unchanged |

## 7. Open Decisions（唯一待定区）

| Topic | Options | Owner | Deadline | Blocking | Decision Rule |
|-------|---------|-------|----------|----------|---------------|
