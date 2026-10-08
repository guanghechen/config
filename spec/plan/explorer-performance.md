# Explorer performance follow-up

Status: completed (2026-10-08). Baseline: `260ac4cee`.

Optimize the current native Explorer while preserving identity validation,
bounded resources, cancellation, and responsive large-directory rendering.
Final contracts remain in [Explorer design](../design/feat/explorer.md),
[Filetree design](../design/filetree.md), and
[Treeview contracts](../../doc/spec/treeview/README.md).

## Completed goals

1. **Continuous input**: Normal fold/mark intent resolves in the native owner
   queue with key-time targets. Rust/Lua regressions and 50 release UI scenarios
   cover repeated input, delayed publication, root changes, manual cursor moves,
   disposal and single error reporting. Visual/destructive stale checks remain.
2. **Prepared tasks and refresh**: closed read grants allow unchanged paged
   refresh before Job claim. Ten 600-child copy scenarios pass; membership,
   topology and unauthorized completeness changes still invalidate the task.
3. **Measured performance**: removed costly per-file descriptor prefetch;
   Linux watches now wait for actual OS/control events. Five alternating pairs
   of native versions (190 process records) show 1k/10k tiny-file copy improving
   from 36.0/346.8 to 27.2/260.5 ms, visible idle CPU from 0.266% to 0.0069% of
   one core, with large-directory responsiveness preserved. Ten additional
   startup pairs show no stable startup gain or regression.
4. **Acceptance and integration**: Rust 580, Lua 290 and Node 23 cases pass;
   additional capacity/cancellation, cross-filesystem, real-input, full-config,
   watch, Job UI, 3 × 100-cycle soak and real LSP checks pass. Updated contracts
   and installed the verified release artifact. Changes belong to the existing
   Treeview, Filetree and Explorer commits via amend, without an extra commit.

## Evidence and limits

- Full results, commands, receipts and final commit mapping:
  `/tmp/explorer-next-20261008/report.md` and its adjacent artifacts.
- Baseline checkout/library and backup ref:
  `/tmp/explorer-next-20261008/baseline/`,
  `refs/codex/backups/explorer-next-20261008`.
- Previous assessment: `/tmp/explorer-reevaluation-20261008/assessment.md`.
- Measurements use warm local WSL2/Linux storage; no cold/NAS or Windows/macOS
  runtime claim. Windows GNU cross-check passes with existing test warnings.
  Startup and large-file throughput remain future measurement opportunities;
  this plan does not require universal superiority over the legacy Explorer.
