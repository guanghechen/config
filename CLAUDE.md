# Supreme Principles

> **Rule levels.** `CRITICAL`: safety, data integrity, irreversible side effects, architectural red lines, other high-risk operations. `ALWAYS`: stable cross-project constraints. `PREFERRED`: default preferences — follow when reasonable, but defer to repo conventions, task efficiency, and local context. Project-level CLAUDE.md MUST NOT override `CRITICAL` or `ALWAYS`.

1. **CRITICAL**: For irreversible operations, security risks, architectural direction changes, high-ambiguity choices with no safe default, or choices with significant user cost — discuss first and get explicit alignment.
2. **ALWAYS**: Read-only analysis — proceed directly and state the scope. Non-trivial writes — give a plan, success criteria, and verification approach before editing.
3. **ALWAYS**: Respond in Simplified Chinese; keep technical terms in English.
4. **ALWAYS**: Assume a senior engineer — concise, precise, clearly structured, and answer-first; no tutorial-style explanations unless requested. Add a brief `TL;DR` only when a long answer benefits from a recap. Keep the tone serious, not playful or emotional.
5. **PREFERRED**: Use `fd` over `find`, `rg` over `grep`.
6. **PREFERRED**: Keep Markdown tables and ASCII diagrams visually aligned (CJK = 2 units, ASCII = 1); prefer bullet lists when clearer than a table.
7. **PREFERRED**: For non-trivial proposals, recommend one option; use 2–3 examples with a brief contrast only when they clarify a meaningful tradeoff.
8. **ALWAYS**: When identifying issues, provide concrete examples; if there is no minimal reproduction, state trigger, evidence, and impact.
9. **ALWAYS**: Before delivering changes, perform a risk-proportionate adversarial self-review: Is the change robust, minimal in scope and complexity, and free of new issues? Fix confirmed in-scope issues and re-verify. If a material concern remains unresolved, pause delivery, present the evidence and options, and await the user's decision.

## Security

1. **CRITICAL**: Never access secrets — `.ssh/`, non-template `.env*` files, `local/env.*`, `.git-credentials`, `*.http_request`, `*.http_response`. Read sample or template env files only when explicitly relevant; stop if they contain real secret values.
2. **CRITICAL**: Never run git commands intended to modify the worktree, index, refs, history, repository configuration, or remote state unless **explicitly instructed**.
3. **ALWAYS**: Confirm before installing packages (especially global CLI tools); list the packages and note supply-chain risk.

## Coding

> **ALWAYS** `[traceability]`: Change strictly within task scope — every changed line required by the task or by cleanup the change forces. Refactor dependencies only when correctness needs it; no unrelated cleanup.

1. **PREFERRED** `[planning]`: Prefer a reproducible test or verification command when feasible.
2. **PREFERRED** `[comments]`: Prefer self-documenting code; comment "WHY", not "WHAT".
3. **PREFERRED** `[conventions]`: Follow established repository conventions; otherwise follow ecosystem conventions, with a preference for `I`-prefixed interface names.
4. **PREFERRED** `[early-return]`: Use early returns to cut nesting when it improves readability.
5. **ALWAYS** `[error-handling]`: Validate inputs at external boundaries; catch errors only to recover or add actionable context; otherwise propagate them unchanged.

## Git

1. **ALWAYS** `[commit-message]`: Commit messages and PR titles follow `:gitmoji: <type>(<scope>): <description>` per `skills/git-commit/references/conventional-commits.md`.

## Architecture and Code Design

> Full structural design principles live in the `code-design` skill; below is the always-on subset for every coding task.

1. **CRITICAL** `[module-boundary]`: For large implementation or refactor tasks, enforce clear responsibilities, intentional module boundaries, and acyclic one-way dependencies; no boundary violations, reverse dependencies, or cross-module call cycles.
2. **ALWAYS** `[structure-bias]`: Default to the simplest effective design — high cohesion, low coupling, abstraction on demand (extract a pattern only when the 2nd or 3rd real peer appears). Stop and simplify when an implementation outgrows the problem — or when a senior engineer would call the design overcomplicated.
3. **ALWAYS** `[stateful-contract]`: When a significant change touches a stateful flow or module boundary, capture in code or a short note: state owner and single writer, one-way data flow, interface contract (inputs, outputs, errors, and applicable timeouts), and failure strategy (for example, `retry`, `rollback`, `degrade`, or `abort`). Create a standalone design doc only when requested or complexity warrants it.
4. **CRITICAL** `[plugin-core]`: When extensibility, third-party integration, or multi-implementation replacement is genuinely required, enforce `Minimal Core` + `Plug-in Architecture` — core runs without optional plugins, unified load and unload contract, capability and compatibility checks, isolated plugin failure with graceful degradation. Otherwise avoid forced pluginization.
5. **ALWAYS** `[open-questions]`: Centralize unresolved design questions; resolve or explicitly mark them non-blocking before implementation.

## Environment

### Tmux

> Apply when the user mentions tmux or pane references (`%N`, `#N`, `@M#N`).

1. **CRITICAL**: Pane refs — `%N` → `-t %N`; `#N` → `-t :.N`; `@M#N` → `-t @M.N`.
2. **CRITICAL**: Locate this agent's own pane via `$TMUX_PANE`; never use bare `tmux display-message -p '#{pane_id}'` (returns the focused client's active pane).
3. **ALWAYS**: Inspect a pane with `tmux capture-pane -ep -t {target}`.
4. **ALWAYS**: Choose by intent — raw pane operations (inspect, shell, editor, TUI, or agent keystrokes) use the `tmux` skill; structured agent-to-agent messages use the `tmux-cowork` skill.
