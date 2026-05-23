# Supreme Principles

> **Constitutional rules.** `CRITICAL` and `ALWAYS` rules take highest precedence — project-level CLAUDE.md MUST NOT override. Other rules are recommendations and may be adapted per context.

1. **CRITICAL**: For complex tasks, multiple options, or any concerns — discuss first, align on direction before doing the work.
2. **ALWAYS**: Respond in Chinese (简体中文); keep technical terms in English.
3. **ALWAYS**: Prefer `fd` over `find`, `rg` over `grep`.
4. **ALWAYS**: Align Markdown tables and ASCII diagrams (CJK = 2 units, ASCII = 1) — monofont rendering requires precise alignment.
5. **ALWAYS**: For non-trivial proposals, give 2-3 concrete examples with brief contrasts and one recommendation.
6. **ALWAYS**: When identifying issues, show concrete examples; if no minimal repro, state trigger, evidence, and impact.

## Security

1. **CRITICAL**: Never access secrets (`.ssh/`, `.env*`, `local/env.*`, `*credentials*`, `*.http_request`, `*.http_response`).
2. **CRITICAL**: Never run git write commands (`add/rm/clean/commit/checkout/restore/reset/stash/push`) unless **explicitly instructed**.
3. **ALWAYS**: Confirm with user before installing packages (especially global CLI tools). List packages to be installed — risk of supply-chain attacks.

## Coding

> **ALWAYS** follow simple design, modularity, single responsibility. Scope changes strictly to the task. Refactor dependencies only if required for correctness; avoid unrelated cleanup.

1. For non-trivial coding tasks, define or derive explicit success criteria during planning; prefer a reproducible test or verification command when feasible.
2. Prefer self-documenting code over comments. Comment "WHY", not "WHAT". No premature abstraction.
3. Choose the simplest effective solution; high cohesion, low coupling. If an implementation grows noticeably larger than the problem requires, stop and simplify before continuing.
4. Keep changes traceable to the user request: every changed line must be required by the task or by cleanup caused by the current change.
5. Organize code: imports → constants → types → public API → private impl → entry point.
6. **ALWAYS**: `I`-prefixed naming for types/interfaces (TS/Lua/Java/C# only) (e.g., `IChatMessage`, `IUser`).
7. **ALWAYS**: Early return; avoid nested conditions.
8. **ALWAYS**: Error handling by function type:
   - Internal (private): Propagate errors to caller (unless designed to suppress).
   - Exposed with side effects: Validate inputs at boundary; handle or wrap errors.
   - Exposed pure (no side effects): Propagate errors transparently.
9. **CRITICAL**: For large implementation/refactor tasks, strictly enforce Single Responsibility Principle (SRP): design intentional directory/module boundaries, keep layer calls explicit and one-directional, and avoid cross-layer coupling or circular dependency/call chains.

## Environment

### Tmux

> Apply when user mentions tmux or pane references (`%N`, `#N`, `@M#N`).

1. **CRITICAL**: Pane reference conventions:
   - `%N` (e.g., `%3`) - Global pane id: `-t %3`
   - `#N` (e.g., `#3`) - Pane index N in current window: `-t :.N`
   - `@M#N` (e.g., `@1#2`) - Pane index N in window @M: `-t @M.N`
2. **CRITICAL**: `tmux capture-pane -ep -t {pane_ref}` - View pane buffer (e.g., `-t %3`, `-t :.1`, `-t @1.2`)
3. **CRITICAL**: `tmux send-keys -t {pane_ref} 'command' Enter` - Send commands to pane (e.g., `-t %3`, `-t :.1`, `-t @1.2`)
4. **CRITICAL**: Inter-agent communication: After sending message to agent pane, trigger with `sleep 2 && tmux send-keys -t {pane_ref} C-m C-m`

## Architecture Governance

1. **ALWAYS**: For new feature work or non-trivial refactor tasks, follow `arch-gate` skill before implementation.
   For tiny scoped changes, skipping is allowed only with an explicit reason.
   Unresolved items must be centralized before implementation and must not be scattered in final design.
2. **ALWAYS**: `Dataflow State Machine` must define input/output boundary, states, transitions, state owner, read/write permission, and failure path (`retry/rollback/degrade/abort`); `Interaction Lifecycle Model` must define SRP boundary, one-way dependencies, interface contract (input/output/error/timeout), lifecycle (`init/start/stop/dispose`), and no cross-module internal state access.
3. **CRITICAL**: When extensibility, third-party integration, or multi-implementation replacement is required, enforce runnable `Minimal Core` + `Plug-in Architecture` (core works without optional plugins, unified load/unload contract, capability/compatibility checks, and isolated plugin failure with graceful degradation). Otherwise prefer the simplest effective design and avoid forced pluginization.

