# Input Method Switching

`era.m.im` owns editor lifecycle, `yoz.im` exposes a source-oriented Lua contract, and the standalone `rust/im` crate owns platform input-source access.

## Ownership and lifecycle

- `rust/im` owns opaque source IDs, English-source classification, exact restoration, WSL process supervision, and the Windows bridge source.
- `yoz.im` exposes only `capture()`, `capture_and_select_english()`, `restore()`, `is_english()`, plus WSL-only `setup()`.
- `Non-English` is only `not is_english(snapshot)`. It is never a selectable target; every return to a non-English source uses its exact captured source ID.
- Public `era.m.im` exposes only `dressing()` and owns one opaque Insert snapshot, one active focus-session record, and the restore generation. The focus session contains its entry snapshot, latest observed editing snapshot, and monotonic entry time.
- `dressing()` is registered after `era.m.ui_attach.dressing()` and before plugin setup, so focus handlers exist before `UIEnter` without depending on plugins.
- `InsertLeave` invalidates pending restores and calls `capture_and_select_english()` once. Any returned snapshot becomes the cross-mode Insert snapshot and the active session's latest editing snapshot, including when English selection fails after capture.
- `InsertEnter` schedules exact restoration for the next event-loop tick. It skips known English snapshots; otherwise it restores only when the generation is current, auto switching remains enabled, and Neovim is still in Insert or Replace mode.
- Each idempotent `UIEnter` / `FocusGained` / `VimResume` entry with an attached UI samples its monotonic start time before backend I/O and starts one focus session. Command modes use the fused capture-and-select operation. Other modes capture without selecting; Insert or Replace mode then restores the known Neovim Insert snapshot.
- Each idempotent `FocusLost` / `VimSuspend` / `VimLeavePre` exit, plus the last attached UI's `UILeave`, invalidates pending restores. Sessions lasting at most 60 seconds restore their entry snapshot. Longer sessions restore their latest observed editing snapshot, falling back to the entry snapshot when no editing source was observed. A `UILeave` with another UI still attached keeps the session active.
- Focus exit deliberately does not capture a source: native Windows and the WSL bridge inspect the foreground thread, which may already belong to the destination application when `FocusLost` is delivered.
- Disabling auto switching immediately invalidates pending restores and clears the Insert and focus-session snapshots. Re-enabling starts a new session from the source visible at that moment.
- tmux focus-event propagation remains responsible for delivering focus boundaries; overlapping native and tmux events are safe because focus sessions are paired and idempotent.

## Backend contract

- `capture()` returns `(snapshot, error)` without changing the source.
- `capture_and_select_english()` returns `(snapshot, ready, error)`:
  - capture failure: `(nil, false, error)` and no selection is attempted;
  - already English or successful selection: `(snapshot, true, nil)`;
  - capture success followed by selection failure: `(snapshot, false, error)`.
- `restore(snapshot)` selects the exact captured source ID.
- `is_english(snapshot)` is a predicate only; no `InputMethod` enum or semantic non-English setter exists.

## Platform mappings

- macOS snapshots are exact Text Input Source Services IDs. English means ASCII-capable; selection uses the system's current ASCII-capable keyboard input source instead of a hard-coded source ID.
- Native Windows snapshots are full decimal HKLs. English classification accepts every standard LANGID whose primary language is English; selection uses the first loaded English HKL reported by Windows.
- WSL snapshots are also full decimal HKLs. The Linux backend no longer truncates them to 16-bit LANGIDs.
- The WSL helper protocol is: no argument queries the current HKL, `--english` captures the current HKL and selects a loaded English HKL, and a decimal HKL performs exact restoration. Its no-allocator bridge accepts at most 64 loaded layouts and fails explicitly above that bound.
- The `--english` helper writes the original HKL before requesting selection. The Linux backend therefore preserves a snapshot even when selection exits with an error or times out after the helper entered its selection phase.
- A normal command-mode entry or `InsertLeave` starts one WSL helper process instead of a query process followed by a selection process.
- The helper submits a bounded `SendMessageTimeoutW` request and polls the captured foreground thread for up to 100ms at 10ms intervals. The Linux parent kills and reaps a helper that exceeds its 1s process deadline.
- The helper-backed capability is exported only when WSL detection succeeds; ordinary Linux has no IM backend.

## Failure strategy

- Native and WSL backends return values and errors; `era.m.im` is the single reporter for lifecycle failures.
- One fused operation produces at most one report. A capture failure is not followed by a second selection process.
- A selection failure preserves its captured snapshot so focus exit can still restore the original source.
- A failed `InsertLeave` capture clears the cross-mode Insert restore target but preserves the active focus session's latest successful editing snapshot.
- Selection and restoration failures never replace an existing snapshot with a guessed source.
- macOS source selection may become visible asynchronously; generation checks prevent stale deferred restores from crossing later mode transitions.
- Windows HKL classification describes keyboard-layout language, not IME-internal conversion state; richer IME state remains outside this contract.
