# Supreme Principles

> **Rule levels.** `CRITICAL` rules protect safety, data integrity, irreversible side effects, architectural red lines, and other high-risk operations. `ALWAYS` rules are stable cross-project constraints. `PREFERRED` rules are default preferences; follow them when reasonable, but defer to repository conventions, task efficiency, and local context. Project-level AGENTS.md MUST NOT override `CRITICAL` or `ALWAYS` rules.

1. **CRITICAL**: For irreversible operations, security risks, architectural direction changes, high-ambiguity choices with no safe default, or choices with significant user cost, discuss first and get explicit alignment.
2. **ALWAYS**: For read-only analysis, proceed directly and state the scope. For non-trivial write operations, provide a plan, success criteria, and verification approach before editing.
3. **ALWAYS**: Respond in Simplified Chinese; keep technical terms in English.
4. **ALWAYS**: Assume the user is a senior software engineer. Communicate concisely, precisely, and with clear logical structure. Avoid tutorial-style explanations unless requested.
5. **PREFERRED**: Use `fd` over `find`, and `rg` over `grep`.
6. **PREFERRED**: When using Markdown tables or ASCII diagrams, keep them visually aligned when practical (CJK = 2 units, ASCII = 1 unit).
7. **PREFERRED**: Avoid tables when bullet lists communicate the point more clearly.
8. **PREFERRED**: For non-trivial proposals, provide 2-3 concrete examples, brief contrasts, and one recommendation.
9. **ALWAYS**: When identifying issues, provide concrete examples. If there is no minimal reproduction, state trigger, evidence, and impact.

## Security

1. **CRITICAL**: Never access secrets, including `.ssh/`, real `.env*` files (excluding pure templates such as `.env.example`), `local/env.*`, `.git-credentials`, `*.http_request`, and `*.http_response`. Sample or template env files may be read only when explicitly relevant; stop if they contain real secret values.
2. **CRITICAL**: Never run git write commands (`add`, `rm`, `clean`, `commit`, `checkout`, `restore`, `reset`, `stash`, `push`) unless **explicitly instructed**.
3. **ALWAYS**: Confirm with the user before installing packages, especially global CLI tools. List packages to be installed and mention supply-chain risk.

## Coding

> **ALWAYS**: Scope changes strictly to the task. Refactor dependencies only when required for correctness; avoid unrelated cleanup.

1. **PREFERRED** `[planning]`: For coding tasks, follow the Supreme Principles planning gate; prefer a reproducible test or verification command when feasible.
2. **ALWAYS** `[traceability]`: Keep changes traceable to the user request: every changed line must be required by the task or by cleanup caused by the current change.
3. **PREFERRED** `[comments]`: Prefer self-documenting code over comments. Comment "WHY", not "WHAT".
4. **PREFERRED** `[layout]`: Organize code as imports → constants → types → public API → private implementation → entry point.
5. **PREFERRED** `[naming]`: For C# and TypeScript, use `I`-prefixed interface names. For Java and Lua, follow existing repository conventions first; do not force `I` prefixes when there is no clear convention.
6. **PREFERRED** `[early-return]`: Use early returns to reduce nesting when it improves readability.
7. **ALWAYS** `[error-handling]`: Apply error handling based on function boundary:
   - Internal/private functions: propagate errors unless suppression is intentional.
   - Exposed functions with side effects: validate inputs at the boundary; handle or wrap errors.
   - Exposed pure functions: propagate errors transparently.

## Git

1. **ALWAYS** `[commit-message]`: Commit messages and PR titles follow the `:gitmoji: <type>(<scope>): <description>` convention in `skills/git-commit/references/conventional-commits.md`.

## Architecture / Code Design

Full structural design principles live in the `code-design` skill; the rules below are the always-on subset for every coding task.

1. **CRITICAL** `[module-boundary]`: For large implementation/refactor tasks, strictly enforce SRP — intentional directory/module boundaries, explicit one-way layer calls, and no cross-layer coupling or circular dependency/call chains.
2. **ALWAYS** `[structure-bias]`: Default to the simplest effective design — high cohesion, low coupling, abstraction on demand (extract a pattern only when the 2nd/3rd real peer appears, never preemptively). If an implementation grows noticeably larger than the problem requires, stop and simplify.
3. **ALWAYS** `[stateful-contract]`: When a significant change touches a stateful flow or a module boundary, make explicit — in code or a short note — the state owner and single writer, one-way data flow, interface input/output/error/timeout contract, and failure paths (`retry/rollback/degrade/abort`). No standalone design document is required by default; use a short note unless complexity or the user asks for more.
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
