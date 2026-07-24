# Status Renderer Optimization Plan

## Baseline

Measured with an isolated release build on 2026-07-22; the live server had four
sessions and one client. Values are wall-clock latency, not CPU utilization.

- process help: 6.6 ms median
- pure layout: 7.7 ms median
- one tmux client: 8.5 ms median
- read-only status02 render: 16.8 ms median
- scheduler tick with no due task: 13.8 ms median
- scheduler driver plus no-due tick: 72.7 ms median
- due metrics tick: 63.0 ms median
- `route`, `vm_stat`, `netstat`: about 5.5 ms median each

The current bottleneck is process/tmux IPC overhead. Pure Rust rendering is not
the priority at the current session count.

## Constraints

- Preserve fail-closed crash/hang behavior and generation fencing.
- Preserve hook ordering and render-revision latest-wins semantics.
- Do not introduce a daemon or new package dependency without new evidence.
- Change and verify one optimization at a time.

## Ordered Work

1. **Completed — reload-time stale scheduler lock recovery**
   - Coordinate normal and loader recovery through one server-scoped CAS lease.
   - Publish a non-empty owner atomically via a prewritten hard-link candidate.
   - Recover legacy directory locks and current file locks with dead owners only
     after the loader fences the scheduler.
   - Never remove a lock owned by a live driver or renderer.
   - Treat tmux lease-query failure and unknown lock content as fail closed.
   - Verify cleanup/acquire races on an isolated tmux server.
   - Alternating A/B no-due benchmark: old/new median 68.8/77.2 ms,
     mean 79.1/82.8 ms. The small absolute cost is accepted for deterministic
     ownership and error-path isolation; later hot-path work remains item 2.
2. **Completed — reduce scheduler driver process count**
   - Replace hot-path `cat` calls and command substitutions with shell built-in
     reads while preserving exact owner parsing.
   - Alternating HEAD/worktree A/B, 50 runs each: median 85.1/70.7 ms,
     p95 90.3/76.4 ms, mean 103.8/72.3 ms.
   - Keep the Rust supervisor idea deferred; the low-risk shell change produced
     a measurable improvement without changing lifecycle behavior.
3. **Completed — reduce metrics tmux IPC**
   - Combine exact-state task claim with metric-state reads in one tmux command
     queue, preserving timeout-after-claim ambiguity and lease recovery.
   - Start the metrics execution deadline before the combined claim/read so the
     optimization does not relax the execution budget.
   - Alternating isolated due-tick A/B, 20 runs each: median 58.5/49.9 ms,
     p95 70.2/61.9 ms, mean 85.0/70.2 ms.
4. **Deferred — precompute session groups/order at scale**
   - Reconsider only if phase-level tracing attributes more than 5–10 ms to pure
     rendering rather than tmux snapshot IPC.
   - A 4/10/20 attached-client prototype did not improve median latency; at 20
     sessions median changed 17.8 → 19.3 ms. The prototype was reverted. Revisit
     only with phase-level profiling that separates tmux snapshot IPC from render.
5. **Completed — retire legacy recursive scheduler compatibility**
   - The rollback compatibility window was explicitly closed.
   - Removed the retired CLI, runtime, tmux adapter, loader generation, and
     self-rescheduling paths; old commands now fail at the CLI boundary.
6. **Completed — split render and diagnostic snapshot options**
   - Reduced the render/apply hot path from 37 option reads to 15; metric
     payload, health, scheduler outcome, and legacy cache state remain available
     to `dump-state` through the complete diagnostic snapshot.
   - Sequential live no-op apply benchmark, 50 runs before/after: median
     16.660/14.993 ms, p95 18.346/16.495 ms, mean 17.000/15.403 ms.
   - Alternating old/new A/B on the same live server, 50 runs each: median
     14.811/14.320 ms, p95 23.489/16.847 ms, mean 15.985/14.573 ms. Both methods
     show a positive direction; use alternating A/B as the comparative signal
     because the absolute improvement is sensitive to execution order and noise.

## Deferred

- Native Mach/sysctl replacements for `vm_stat`/`netstat`: measurable but small
  benefit relative to unsafe FFI and semantic risk.
- Persistent daemon: process savings do not justify lifecycle complexity.
- Session-list linear window selection: wait for profiling evidence at scale.

## 2026-07-24 Adversarial Review Follow-up

The next optimization remains benchmark-driven. Process/tmux IPC is the known
latency floor, but measurements from standalone `hyperfine` commands are only
directional: they mix shell overhead with historical median/p95 data and cannot
justify an implementation by themselves.

The first approved implementation target was the scheduler driver's live-owner
contention path:

- The lock file remains the single owner of scheduler-driver execution.
- A live driver or renderer owner is a read-only fast rejection; it must be
  checked both before atomic acquisition and again after a failed acquisition,
  because simultaneous contenders can both observe an initially absent lock.
- Only dead or unknown ownership may enter the existing server-scoped recovery
  lease. Recovery remains fail closed on tmux IPC failure or unknown lock data.
- The accepted tradeoff is that an owner dying immediately after a live check
  may defer recovery until the next status tick; no mutation is lost, and the
  existing lease path recovers it on that tick.

The following ideas are not approved without new isolated A/B evidence:

- Passing scheduler task snapshots from shell into Rust would split the tmux
  state boundary for an estimated one-IPC saving, so it remains deferred.
- Hook coalescing requires a dirty-generation replay contract to avoid dropping
  the final lifecycle state; a simple single-flight gate is not acceptable.

Follow-up isolated measurements resolved two of those questions:

- Over 10-second steady-state windows, tmux server CPU was 0.01 seconds with one
  client, 0.03–0.04 seconds with two, and 0.06–0.08 seconds with four. Active
  and inert scheduler modes were indistinguishable. Status-format expansion is
  therefore not a priority at the measured client counts.
- Adjacent 91/92-column resizes kept the same render key while changing only
  `status-right-length`. Alternating old/new A/B runs (30 each) reduced the plan
  from 10 commands to 1, commit median from 16.270 to 15.015 ms, and total median
  from 25.000 to 23.230 ms; total p95 changed from 33.280 to 26.530 ms.

The length-only fast path keeps the existing state boundary: session-local tmux
options have one writer, the Rust commit planner, and every mutation still runs
through render-revision and lifecycle guards. It emits individual length writes
only when cache witnesses, render key, layout, status, and row formats already
match. Any other drift retains the full reconcile bundle and its existing
fail-closed retry behavior. This is intentionally not a general field-level
delta commit.
