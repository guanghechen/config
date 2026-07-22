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
4. **Pending — precompute session groups/order at scale**
   - Implement only if same-group sessions reach 20–30 or traced pure render
     time exceeds 5–10 ms.
5. **Pending — retire legacy recursive scheduler compatibility**
   - Remove only after the rollback compatibility window is explicitly closed.

## Deferred

- Native Mach/sysctl replacements for `vm_stat`/`netstat`: measurable but small
  benefit relative to unsafe FFI and semantic risk.
- Persistent daemon: process savings do not justify lifecycle complexity.
- Session-list linear window selection: wait for profiling evidence at scale.
