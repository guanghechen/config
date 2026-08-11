# Async Search-in-Files Implementation Plan

Design reference: [`../design/feat/yoz/search.md`](../design/feat/yoz/search.md).

## Phase 1: Cancellable Rust Core

- Refactor `search_in_files` behind a shared `Completed | Cancelled | Failed` internal outcome.
- Preserve the synchronous API and exact ordered result semantics.
- Add cancellation checkpoints and a typed, non-retriable cancellation reader error.
- Cover synchronous parity, pre-cancel, read cancel, sink cancel, and cancellation/error
  classification with Rust tests.

## Phase 2: Native Job API

- Add an `mlua` userdata backed by one worker thread, an atomic cancel flag, and a one-shot
  standard-library channel.
- Implement repeatable terminal polling, request-only cancellation, non-blocking disposal, panic
  and disconnected-channel failure, and call-time capture for missing, empty, or relative cwd.
- Export `start_search_in_files` and synchronize Lua type declarations.

## Phase 3: Lua File-Search Controller

- Add a concrete controller with generation invalidation, request-snapshot freshness validation,
  one active job, one latest pending immutable request, and scheduled polling.
- Route every terminal and infrastructure failure through one cleanup/advance path.
- Add deterministic fake-job/fake-timer tests for stale debounce completion, A -> B -> C,
  cancellation races, start/poll/timer errors, empty projection, and queued callbacks after
  disposal.

## Phase 4: Searcher Integration

- Split native start from raw-result normalization in the filetree view.
- Centralize search-affecting Observable notifications, coalesce each event-loop burst, and guard
  terminal publication against the current input snapshot before observer invalidation runs.
- Keep a published-input snapshot and reject destructive replacement while the visible projection
  belongs to different current inputs.
- Replace `_is_searching` and `_search_pending` with the controller.
- Clear the search projection on the first queued observer turn for an empty query.
- Perform synchronous controller disposal before the composer's scheduled UI teardown.

## Phase 5: Verification

- Run Rust formatting, unit tests, and clippy.
- Build the native module and validate it in a fresh headless Neovim process.
- Run targeted Lua controller and searcher integration tests plus Lua formatting checks.
- Measure the complete 500-result publication path in normal and replacement-preview modes; add
  chunked conversion/time-sliced publication if either exceeds the design hard ceiling.
- Record a 5000-result stress run and the accepted residual risks without adding a silent cap.

## Verification Record

- Rust: 152 unit tests pass, including sync/async ordered-item parity, call-time relative cwd capture,
  pre-cancel, typed read
  cancellation, request-only cancel acknowledgement, disconnected worker, repeatable terminal poll,
  and disposed misuse.
- Lua: the complete `lua/__test__/run.lua` suite passes (79 suites), including deterministic
  controller failures/races and a real composer-to-native-job integration.
- Native module: forced release build and fresh-process `yoz.search` Job polling pass.
- Full 500-result publish boundary in the aggregate suite: normal 6.344 ms; replacement preview
  8.525 ms. Both include terminal conversion, normalization, apply, and synchronous render.
- 5000-result stress record: 46.911 ms in the same run; this remains a stress observation, not a
  responsiveness guarantee or silent cap.
- Strict repository-wide `clippy -D warnings` remains blocked by two pre-existing
  `clippy::question_mark` findings in replace modules. Running the same check with only that
  unrelated lint allowed passes all targets.
- Targeted `rustfmt --check` and `stylua --check` pass for new files and changed files without
  baseline drift. Whole-file checks on `lib.rs` and the composer still expose pre-existing drift
  in unrelated URI bindings and the legacy `render_preview` expression.
