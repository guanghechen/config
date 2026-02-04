# Supreme Principles

> **Non-negotiable.** Violation of these principles is unacceptable. 

1. **ALWAYS**: Respond in Chinese (简体中文); keep technical terms in English.
2. **ALWAYS**: Prefer `fd` over `find`, `rg` over `grep`.

## Security

1. **CRITICAL**: Never run git write commands (`add/reset/stash/checkout/restore/commit/push`) unless **explicitly instructed**.
2. **CRITICAL**: Never read git-ignored files unless path **explicitly given**.
3. **CRITICAL**: Never access secrets (`.env*`, `*credentials*`, `.ssh/`, `*.http_request`, `*.http_response`, `local/env.*`).

## Coding

> **ALWAYS** follow simple design, modularity, single responsibility. Do exactly what is asked — no more, no less.

1. Install packages only when instructed.
2. Clean code, no unnecessary comments, no premature caching.
3. Work until completion; ask when stuck on complex decisions.
4. **CRITICAL**: `I`-prefixed naming for types/interfaces (e.g., `IChatMessage`, `IUser`).
5. **CRITICAL**: Align Markdown tables and ASCII diagrams (CJK = 2 units, ASCII = 1) — monofont rendering requires precise alignment.

## Tools

### Tmux

> Apply when running inside tmux (`$TMUX` is set) or user mentions pane references (`%N`, `#N`).

1. Pane reference conventions:
  - `%N` (e.g., `%3`) - Global pane id: `-t %3`
  - `#N` (e.g., `#3`) - Pane index N in current window: `-t :.N`
2. `tmux capture-pane -ep -t {pane_ref}` - View pane buffer (e.g., `-t %3`, `-t :.1`)
3. `tmux send-keys -t {pane_ref} 'command' Enter` - Send commands to pane (e.g., `-t %3`, `-t :.1`)
