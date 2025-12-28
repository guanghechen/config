# Supreme Principles

> **Non-negotiable.** Violation of these principles is unacceptable.

1. **CRITICAL**: Never read files ignored by git unless filepaths are explicitly provided.
2. **CRITICAL**: Never access environment variable files (`*.http_request`, `*.http_response`, `.env.local`, `.git-credentials`, `.ssh/`) or any files containing secrets, passwords, or credentials.
3. **CRITICAL**: Never stage or commit git changes autonomously. Every git commit must be explicitly requested by the user.

## Coding Guidances

1. **ALWAYS**: Only install packages when explicitly instructed.
2. **ALWAYS**: Use `I`-prefixed naming for types and interfaces (e.g., `IChatMessage`, `IUser`).
3. **ALWAYS**: Write clean, concise, elegant code. Avoid unnecessary comments. Caching is lowest priority unless requested.
4. **ALWAYS**: Keep processing until task completion or unsolvable problem; don't stop in between.
5. **ALWAYS**: Engage in discussion with the user on challenging problems or complex design decisions.

### Critical Architecture Principles

1. **Unidirectional Dependencies** - No circular dependencies. Dependencies must form a DAG.
2. **Single Responsibility** - High cohesion, low coupling. Each file has one clear purpose.
3. **Consistent Module Structure** - All modules follow similar, self-explanatory organization. Familiarity with one module means understanding all.
4. **Minimal Public Interface** - Private by default. Expose as little as possible.
5. **Simplicity Over Optimization** - Simplicity first. Avoid caching unless truly necessary. Isolate complex optimizations into dedicated modules and expose through interfaces.

### Formatting

- Always include a single trailing newline at end of file
- Validate at system boundaries only; trust internal code

## Documentation Guidances

1. **ALWAYS**: Align table/border separators in Markdown. CJK characters occupy 2 display units, ASCII occupies 1.

## Recommended

1. Use `fd` rather than `find` to search files.
2. Use `rg` rather than `grep` to search contents.
3. Fork existing code for new features; avoid rewriting unless modification is simple or no other logic depends on it.

----End of the Supreme Principles----
