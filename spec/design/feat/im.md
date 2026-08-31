# Input Method Switching

`era.m.im` owns editor lifecycle, `yoz.im` exposes the Lua contract, and the standalone `rust/im` crate owns platform input-method access.

## Ownership and lifecycle

- `rust/im` owns source-token access, snapshot restoration, platform mapping, WSL process supervision, and the Windows bridge source.
- `yoz.im` is a thin Lua adapter over the `yoz-im` crate and preserves the source-ID plus semantic `English` / `Chinese` contract.
- Public `era.m.im` keeps the semantic `get_input_method()` / `set_input_method()` interface.
- `era.m.im` consumes the `yoz.im` contract directly. On WSL it injects the repository-built `bin/wsl.yoz-im.exe` path once; no third-party IM executable is required.
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

- Native macOS mapping lives in `rust/im`: `English` maps to `com.apple.keylayout.ABC`, `Chinese` maps to `com.apple.inputmethod.SCIM.ITABC`, and snapshots retain any exact Text Input Source Services ID.
- Native Windows mapping lives in `rust/im`: semantic methods use the low 16-bit language ID while snapshots retain the full decimal `HKL`.
- Native Windows selection uses a bounded `SendMessageTimeoutW` request and verifies the foreground thread's resulting layout before reporting success.
- WSL uses the x64 `wsl.yoz-im.exe` artifact built from `rust/im/src/bin/yoz-im.rs`. Its snapshots are decimal Windows language IDs rather than full HKLs.
- The WSL bridge submits a bounded `SendMessageTimeoutW` request and polls the foreground thread in-process for up to 100ms at 10ms intervals. The Linux backend therefore starts one bridge process per query or selection and trusts a zero exit status only after bridge-side verification.
- The helper-backed capability is exported only when WSL detection succeeds; ordinary Linux has no IM backend.

## Failure strategy

- Native and WSL backends return `(value, error)`; `era.m.im` is the single reporter for public and lifecycle failures.
- WSL helper processes are killed and reaped after a 1s timeout so a broken interop boundary cannot block Neovim indefinitely.
- A failed source read clears the restore target for that Insert session, then semantic English selection is still attempted.
- Selection failures do not mutate the recorded snapshot.
- macOS source selection may become visible asynchronously; generation checks prevent stale deferred restores from crossing later mode transitions.
- Windows HKL mapping represents installed keyboard layouts; IME-internal English/Chinese modes require a richer Windows backend and remain runtime-dependent.
