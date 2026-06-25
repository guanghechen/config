# Supreme Principles

> **Rule levels.** `CRITICAL`: safety, data integrity, irreversible side effects, architectural red lines, other high-risk operations. `ALWAYS`: stable cross-project constraints. `PREFERRED`: default preferences — follow when reasonable, but defer to repo conventions, task efficiency, and local context. Project-level CLAUDE.md MUST NOT override `CRITICAL` or `ALWAYS`.

1. **CRITICAL**: For irreversible operations, security risks, architectural direction changes, high-ambiguity choices with no safe default, or choices with significant user cost — discuss first and get explicit alignment.
2. **ALWAYS**: Read-only analysis — proceed directly and state the scope. Non-trivial writes — give a plan, success criteria, and verification approach before editing.
3. **ALWAYS**: Respond in Simplified Chinese; keep technical terms in English.
4. **ALWAYS**: Assume a senior engineer — concise, precise, clearly structured, answer-first; no tutorial-style explanations unless requested. End detailed or multi-section answers with a brief `TL;DR` (conclusion, recommendation, required action); keep it accurate, concise, clear, serious — not playful or emotional.
5. **PREFERRED**: Use `fd` over `find`, `rg` over `grep`.
6. **PREFERRED**: Keep Markdown tables and ASCII diagrams visually aligned (CJK = 2 units, ASCII = 1); prefer bullet lists when clearer than a table.
7. **PREFERRED**: For non-trivial proposals, give 2–3 examples + brief contrast + one recommendation.
8. **ALWAYS**: When identifying issues, provide concrete examples; if there is no minimal reproduction, state trigger, evidence, and impact.

## Security

1. **CRITICAL**: Never access secrets — `.ssh/`, non-template `.env*` files, `local/env.*`, `.git-credentials`, `*.http_request`, `*.http_response`. Read sample or template env files only when explicitly relevant; stop if they contain real secret values.
2. **CRITICAL**: Never run git write commands (`add`, `rm`, `clean`, `commit`, `checkout`, `restore`, `reset`, `stash`, `push`) unless **explicitly instructed**.
3. **ALWAYS**: Confirm before installing packages (especially global CLI tools); list the packages and note supply-chain risk.

## Coding

> **ALWAYS** `[traceability]`: Change strictly within task scope — every changed line required by the task or by cleanup the change forces. Refactor dependencies only when correctness needs it; no unrelated cleanup.

1. **PREFERRED** `[planning]`: Prefer a reproducible test or verification command when feasible.
2. **PREFERRED** `[comments]`: Prefer self-documenting code; comment "WHY", not "WHAT".
3. **PREFERRED** `[layout]`: Order code as imports → constants → types → public API → private implementation → entry point.
4. **PREFERRED** `[naming]`: For C# and TypeScript, use `I`-prefixed interface names; for Java and Lua, follow existing repo conventions first — do not force `I` prefixes absent a clear convention.
5. **PREFERRED** `[early-return]`: Use early returns to cut nesting when it improves readability.
6. **ALWAYS** `[error-handling]`: By boundary — internal or private functions propagate (unless suppression is intentional); exposed side-effecting functions validate inputs at the boundary and handle or wrap errors; exposed pure functions propagate transparently.

## Git

1. **ALWAYS** `[commit-message]`: Commit messages and PR titles follow `:gitmoji: <type>(<scope>): <description>` per `skills/git-commit/references/conventional-commits.md`.

## Architecture and Code Design

> Full structural design principles live in the `code-design` skill; below is the always-on subset for every coding task.

1. **CRITICAL** `[module-boundary]`: For large implementation or refactor tasks, strictly enforce SRP — intentional directory and module boundaries, explicit one-way layer calls, no cross-layer coupling, circular dependencies, or circular call chains.
2. **ALWAYS** `[structure-bias]`: Default to the simplest effective design — high cohesion, low coupling, abstraction on demand (extract a pattern only when the 2nd or 3rd real peer appears). If an implementation outgrows the problem, stop and simplify.
3. **ALWAYS** `[stateful-contract]`: When a significant change touches a stateful flow or module boundary, make explicit (in code or a short note) — state owner and single writer; one-way data flow; interface contract for input, output, errors, and timeouts; and failure paths (`retry`, `rollback`, `degrade`, or `abort`). No standalone design doc by default — use a short note unless complexity or the user asks for more.
4. **CRITICAL** `[plugin-core]`: When extensibility, third-party integration, or multi-implementation replacement is genuinely required, enforce `Minimal Core` + `Plug-in Architecture` — core runs without optional plugins, unified load and unload contract, capability and compatibility checks, isolated plugin failure with graceful degradation. Otherwise avoid forced pluginization.
5. **ALWAYS** `[open-questions]`: Centralize unresolved design questions; resolve or explicitly mark them non-blocking before implementation.

## Environment

### Tmux

> Apply when the user mentions tmux or pane references (`%N`, `#N`, `@M#N`).

1. **CRITICAL**: Pane refs — `%N` → `-t %N`; `#N` → `-t :.N`; `@M#N` → `-t @M.N`.
2. **CRITICAL**: Locate this agent's own pane via `$TMUX_PANE`; never use bare `tmux display-message -p '#{pane_id}'` (returns the focused client's active pane).
3. **ALWAYS**: Inspect a pane with `tmux capture-pane -ep -t {target}`.
4. **ALWAYS**: Choose by intent — raw pane operations (inspect, shell, editor, TUI, or agent keystrokes) use the `tmux` skill; structured agent-to-agent messages use the `tmux-cowork` skill.
