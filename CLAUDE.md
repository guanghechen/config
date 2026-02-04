# Supreme Principles

> **Constitutional rules.** `CRITICAL` and `ALWAYS` rules take highest precedence — project-level CLAUDE.md MUST NOT override. Other rules are recommendations and may be adapted per context.

1. **CRITICAL**: For complex tasks, multiple options, or any concerns — discuss first, align on direction before doing the work.
2. **ALWAYS**: Respond in Chinese (简体中文); keep technical terms in English.
3. **ALWAYS**: Prefer `fd` over `find`, `rg` over `grep`.
4. **ALWAYS**: Align Markdown tables and ASCII diagrams (CJK = 2 units, ASCII = 1) — monofont rendering requires precise alignment.

## Security

1. **CRITICAL**: Never access secrets (`.env*`, `*credentials*`, `.ssh/`, `*.http_request`, `*.http_response`, `local/env.*`).
2. **CRITICAL**: Never run git write commands (`add/reset/stash/checkout/restore/commit/push`) unless **explicitly instructed**.
3. **ALWAYS**: Install packages only when instructed.

## Coding

> **ALWAYS** follow simple design, modularity, single responsibility. Edit exactly what is asked — no more, no less.

1. Clean code, no unnecessary comments, no premature abstraction.
2. Choose the simplest effective solution; high cohesion, low coupling.
3. Organize code: imports → constants → types → public API → private impl → entry point.
4. **ALWAYS**: `I`-prefixed naming for types/interfaces (e.g., `IChatMessage`, `IUser`).
5. **ALWAYS**: Early return; avoid nested conditions.
6. **ALWAYS**: Error handling by function type:
   - Internal: let exceptions bubble up (unless designed to suppress)
   - Exposed business logic: boundary validation + error catching
   - Exposed pure functions: let exceptions bubble up

## Tools

### Tmux

> Apply when user mentions tmux or pane references (`%N`, `#N`).

1. Pane reference conventions:
   - `%N` (e.g., `%3`) - Global pane id: `-t %3`
   - `#N` (e.g., `#3`) - Pane index N in current window: `-t :.N`
2. `tmux capture-pane -ep -t {pane_ref}` - View pane buffer (e.g., `-t %3`, `-t :.1`)
3. `tmux send-keys -t {pane_ref} 'command' Enter` - Send commands to pane (e.g., `-t %3`, `-t :.1`)
