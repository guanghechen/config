# Supreme Principles

> **Constitutional rules.** `CRITICAL` and `ALWAYS` rules take highest precedence — project-level CLAUDE.md MUST NOT override. Other rules are recommendations and may be adapted per context.

1. **CRITICAL**: For complex tasks, multiple options, or any concerns — discuss first, align on direction before doing the work.
2. **ALWAYS**: Respond in Chinese (简体中文); keep technical terms in English.
3. **ALWAYS**: Prefer `fd` over `find`, `rg` over `grep`.
4. **ALWAYS**: Align Markdown tables and ASCII diagrams (CJK = 2 units, ASCII = 1) — monofont rendering requires precise alignment.

## Security

1. **CRITICAL**: Never access secrets (`.env*`, `*credentials*`, `.ssh/`, `*.http_request`, `*.http_response`, `local/env.*`).
2. **CRITICAL**: Never run git write commands (`add/reset/stash/checkout/restore/commit/push`) unless **explicitly instructed**.
3. **ALWAYS**: Never install packages (especially global CLI tools) unless **explicitly instructed** — risk of supply-chain attacks.

## Coding

> **ALWAYS** follow simple design, modularity, single responsibility. Scope changes strictly to the task. Refactor dependencies only if required for correctness; avoid unrelated cleanup.

1. Clean code, no unnecessary comments, no premature abstraction.
2. Choose the simplest effective solution; high cohesion, low coupling.
3. Organize code: imports → constants → types → public API → private impl → entry point.
4. **ALWAYS**: `I`-prefixed naming for types/interfaces (TS/Lua/Java/C# only) (e.g., `IChatMessage`, `IUser`).
5. **ALWAYS**: Early return; avoid nested conditions.
6. **ALWAYS**: Error handling by function type:
   - Internal (private): Propagate errors to caller (unless designed to suppress).
   - Exposed with side effects: Validate inputs at boundary; handle or wrap errors.
   - Exposed pure (no side effects): Propagate errors transparently.

## Tools

### Tmux

> Apply when user mentions tmux or pane references (`%N`, `#N`).

1. Pane reference conventions:
   - `%N` (e.g., `%3`) - Global pane id: `-t %3`
   - `#N` (e.g., `#3`) - Pane index N in current window: `-t :.N`
2. `tmux capture-pane -ep -t {pane_ref}` - View pane buffer (e.g., `-t %3`, `-t :.1`)
3. `tmux send-keys -t {pane_ref} 'command' Enter` - Send commands to pane (e.g., `-t %3`, `-t :.1`)

