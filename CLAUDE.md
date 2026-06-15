# Supreme Principles

> **Constitutional rules.** `CRITICAL` and `ALWAYS` rules take highest precedence — project-level CLAUDE.md MUST NOT override. Other rules are recommendations and may be adapted per context.

1. **CRITICAL**: For complex tasks, multiple options, or any concerns — discuss first, align on direction before doing the work.
2. **ALWAYS**: Respond in Chinese (简体中文); keep technical terms in English.
3. **ALWAYS**: Assume the user is a senior computer engineer; communicate concisely, precisely, and with clear logical structure. Avoid tutorial-style explanations unless requested.
4. **ALWAYS**: Prefer `fd` over `find`, `rg` over `grep`.
5. **ALWAYS**: Align Markdown tables and ASCII diagrams (CJK = 2 units, ASCII = 1) — monofont rendering requires precise alignment.
6. **ALWAYS**: For non-trivial proposals, give 2-3 concrete examples with brief contrasts and one recommendation.
7. **ALWAYS**: When identifying issues, show concrete examples; if no minimal repro, state trigger, evidence, and impact.

## Security

1. **CRITICAL**: Never access secrets (`.ssh/`, `.env*`, `local/env.*`, `.git-credentials`, `*.http_request`, `*.http_response`).
2. **CRITICAL**: Never run git write commands (`add/rm/clean/commit/checkout/restore/reset/stash/push`) unless **explicitly instructed**.
3. **ALWAYS**: Confirm with user before installing packages (especially global CLI tools). List packages to be installed — risk of supply-chain attacks.

## Coding

> **ALWAYS**: Scope changes strictly to the task. Refactor dependencies only if required for correctness; avoid unrelated cleanup.

1. `[planning]` For non-trivial coding tasks, define or derive explicit success criteria during planning; prefer a reproducible test or verification command when feasible.
2. `[traceability]` Keep changes traceable to the user request: every changed line must be required by the task or by cleanup caused by the current change.
3. `[comments]` Prefer self-documenting code over comments. Comment "WHY", not "WHAT".
4. `[layout]` Organize code: imports → constants → types → public API → private impl → entry point.
5. **ALWAYS** `[naming]`: `I`-prefixed naming for types/interfaces (TS/Lua/Java/C# only) (e.g., `IChatMessage`, `IUser`).
6. **ALWAYS** `[early-return]`: Early return; avoid nested conditions.
7. **ALWAYS** `[error-handling]`: Error handling by function type:
   - Internal (private): Propagate errors to caller (unless designed to suppress).
   - Exposed with side effects: Validate inputs at boundary; handle or wrap errors.
   - Exposed pure (no side effects): Propagate errors transparently.

## Architecture / Code Design

Full structural design principles live in the `code-design` skill; the rules below are the always-on subset for every coding task.

1. **CRITICAL** `[module-boundary]`: For large implementation/refactor tasks, strictly enforce SRP — intentional directory/module boundaries, explicit one-way layer calls, and no cross-layer coupling or circular dependency/call chains.
2. **ALWAYS** `[structure-bias]`: Default to the simplest effective design — high cohesion, low coupling, abstraction on demand (extract a pattern only when the 2nd/3rd real peer appears, never preemptively). If an implementation grows noticeably larger than the problem requires, stop and simplify.
3. **ALWAYS** `[stateful-contract]`: When a change touches a stateful flow or a module boundary, make explicit — in code or a short note — the state owner and single writer, one-way data flow, interface input/output/error/timeout contract, and failure paths (`retry/rollback/degrade/abort`). No standalone design document is required by default; use a short note unless complexity or the user asks for more.
4. **CRITICAL** `[plugin-core]`: When extensibility, third-party integration, or multi-implementation replacement is genuinely required, enforce a runnable `Minimal Core` + `Plug-in Architecture` (core works without optional plugins, unified load/unload contract, capability/compatibility checks, and isolated plugin failure with graceful degradation). Otherwise prefer the simplest effective design and avoid forced pluginization.
5. **ALWAYS** `[open-questions]`: Centralize unresolved design questions in one place; resolve them or explicitly mark them non-blocking before implementation.

## Environment

### Tmux

> Apply when user mentions tmux or pane references (`%N`, `#N`, `@M#N`).

1. **CRITICAL**: Pane ref conventions:
   - `%N`: global pane id, use `-t %N`
   - `#N`: pane index in current window, use `-t :.N`
   - `@M#N`: pane index N in window @M, use `-t @M.N`
2. **CRITICAL**: Locate this agent's own pane via `$TMUX_PANE`; never use bare `tmux display-message -p '#{pane_id}'`, which returns the focused client's active pane.
3. **ALWAYS**: Use `tmux capture-pane -ep -t {target}` to inspect a pane.
4. **ALWAYS**: Choose tmux skill by intent: raw pane operations (inspect, shell/editor/TUI/agent pane keystrokes) use `tmux`; structured agent-to-agent messages use `tmux-cowork`.
