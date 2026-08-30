# Input Method Switching

`era.m.im` owns editor lifecycle while `yoz.im` exposes both source-ID primitives and a thin platform mapping for `English` / `Chinese`.

## Ownership and lifecycle

- `yoz.im` owns source-token access, snapshot restoration, and the thin semantic mapping for macOS, Windows, and WSL.
- Public `era.m.im` keeps the semantic `get_input_method()` / `set_input_method()` interface.
- `era.m.im` consumes the `yoz.im` contract directly. On WSL it injects the existing `im-select.exe` path once; process execution and mapping remain inside `yoz`.
- One `era.m.im.dressing()` instance owns the opaque Insert-mode snapshot and restore generation.
- `dressing()` replaces its augroup and registers lifecycle handlers synchronously; repeated setup cannot leave delayed duplicate handlers.
- `InsertLeave` invalidates pending restores, captures the current backend token, and selects semantic `English` mode only when needed.
- `InsertEnter` schedules restoration for the next event-loop tick so synchronous handlers observe a stable buffer and cursor first.
- A scheduled restore runs only when its generation is current, auto switching remains enabled, and Neovim is still in Insert or Replace mode.
- `FocusGained` selects semantic `English` only in pure Normal, Operator-pending, and Visual modes; temporary Insert/Select/Terminal submodes remain untouched.
- tmux supplements pane selection with a guarded `after-select-pane` hook that sends the standard FocusIn sequence only to a newly selected Neovim pane.
- The first `InsertEnter` does not select a source because no Insert-mode source has been recorded yet.
- Disabling auto switching immediately invalidates pending restores and clears the remembered snapshot.

## Platform mappings

- Native macOS mapping lives in `yoz.im`: `English` maps to `com.apple.keylayout.ABC`, `Chinese` maps to `com.apple.inputmethod.SCIM.ITABC`, and snapshots retain any exact Text Input Source Services ID.
- Native Windows mapping lives in `yoz.im`: semantic methods use the low 16-bit language ID while snapshots retain the full decimal `HKL`.
- Native Windows selection uses a bounded `SendMessageTimeoutW` request and verifies the foreground thread's resulting layout before reporting success.
- WSL uses the existing architecture-specific `im-select.exe`. Its snapshots are decimal Windows language IDs rather than full HKLs.
- Because the helper posts selection asynchronously and does not report delivery failures, WSL reads back at least twice and polls the observed language ID for up to 100ms at 10ms intervals before reporting failure.
- The helper-backed capability is exported only when WSL detection succeeds; ordinary Linux has no IM backend.

## Failure strategy

- Native and WSL backends return `(value, error)`; `era.m.im` is the single reporter for public and lifecycle failures.
- WSL helper processes are killed and reaped after a 1s timeout so a broken interop boundary cannot block Neovim indefinitely.
- A failed source read clears the restore target for that Insert session, then semantic English selection is still attempted.
- Selection failures do not mutate the recorded snapshot.
- macOS source selection may become visible asynchronously; generation checks prevent stale deferred restores from crossing later mode transitions.
- Windows HKL mapping represents installed keyboard layouts; IME-internal English/Chinese modes require a richer Windows backend and remain runtime-dependent.
