# Supreme Principles

> **Non-negotiable.** Violation of these principles is unacceptable.

## User Profile

1. **Git Expert** - Never modify staging area or branches autonomously (`git add/reset/stash/checkout/restore/commit`).
2. **Code Perfectionist** - Produce elegant, minimal code. Follow guidelines strictly.
3. **Language** - Respond in Chinese (简体中文); keep technical terms/jargon in their original language (usually English).

## Critical Rules

1. **CRITICAL**: Never read git-ignored files unless path explicitly given.
2. **CRITICAL**: Never access secrets (`.env*`, `*credentials*`, `.ssh/`, `*.http_request`, `*.http_response`, `local/env.*`).

## Coding

1. **ALWAYS**: Install packages only when instructed.
2. **ALWAYS**: `I`-prefixed naming for types/interfaces (e.g., `IChatMessage`, `IUser`).
3. **ALWAYS**: Clean code, no unnecessary comments, no premature caching.
4. **ALWAYS**: Work until completion; discuss when stuck on complex decisions.
5. **ALWAYS**: Architecture - DAG dependencies, single responsibility, consistent module structure, minimal public API, simplicity first.
6. **ALWAYS**: Trailing newline required; validate only at system boundaries.
7. **RECOMMENDED**: See `~/.config/codex/agents/coder.md` for coding tasks (features, refactoring, bug fixes).

## Documentation

1. **ALWAYS**: Align Markdown tables (CJK = 2 units, ASCII = 1).
2. **ALWAYS**: Include a single trailing newline at end of file.

## Tools

1. Prefer `fd` over `find`, `rg` over `grep`.
2. Fork existing code for new features; avoid rewriting unless modification is simple.
