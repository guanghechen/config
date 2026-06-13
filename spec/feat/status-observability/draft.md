# Status Observability Draft

## 1. Problem Statement

`status-interval=1` is acceptable today, but future performance work should be driven by measurements rather than guesses. We need lightweight observability for the current Rust status runtime without changing normal rendering behavior or adding a daemon.

## 2. Context and Constraints

- Normal `apply tick` runs through tmux `#()` and redirects stdout/stderr to `/dev/null`; tracing must be opt-in.
- `dump-state` should remain read-only and must not commit tmux options.
- Observability must not introduce a scheduler or persistent process.
- No external dependencies.
- Existing status output must remain unchanged unless trace is explicitly enabled.

## 3. Open Questions

| Question | Options | Decision | Rationale |
|----------|---------|----------|-----------|
| Where should timing go? | Always print / env-gated stderr / tmux option | Env-gated stderr | Zero default noise; usable from manual CLI. |
| What should dump-state show? | Full render profile / cache freshness only / nothing | Cache freshness + lifecycle summary | Read-only and enough to reason about tick gate. |
| Should this implement tick preflight? | Yes / No | No | This phase measures; scheduling comes later. |

## 4. Risk Notes

| Risk | Trigger | Evidence | Impact | Mitigation |
|------|---------|----------|--------|------------|
| Trace changes status output | Trace writes stdout | tmux consumes stdout in `#()` | Broken status format | Trace writes stderr only and remains env-gated. |
| dump-state causes sampling | It renders widgets to get stats | CachedMetric sample may run | Unexpected side effect | dump-state reads snapshot/cache only. |
| Observability itself becomes overhead | Trace enabled in tick path | String formatting every second | Small overhead | Check env before formatting major trace lines. |

## 5. Draft Decisions

- Add `GHC_TMUX_STATUS_TRACE=1` for stderr trace lines.
- Trace runtime apply phases: context, render, plan, commit/no-op.
- Trace cached metric refresh decisions: fresh cache, event-skip, sample-ok, sample-error fallback/empty.
- Extend `dump-state` with metric cache freshness and lifecycle placement summary.
