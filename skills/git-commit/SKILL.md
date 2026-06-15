---
name: git-commit
description: Create safe, convention-aligned git commits from current changes. Use when the user asks to commit, asks for a commit message, asks to commit only part of changes, or asks to follow existing repo commit conventions.
argument-hint: "[scope | message hint]"
---

# Git Commit

## Scope

Use this skill only when the user explicitly asks to create a commit.

This skill handles:
- Full commit from current changes
- Partial commit by file path or topic scope
- Commit message generation aligned to repo history
- Pre-commit safety checks (secret/sensitive/unsuitable content)

This skill does not handle:
- Pushing to remote unless explicitly requested
- Amending/rebasing history unless explicitly requested

## Inputs

Optional user arguments may include:
- commit scope (paths, glob, or topic)
- message hints

Interpret arguments as constraints first, hints second.

## Workflow

1. Resolve commit scope (path-first)
   - Run `git status --porcelain` to list changed paths (staged+unstaged); do not read diff content yet.
   - Target set = the user-requested scope if given, else all changed paths. If empty, report and stop.
   - If no scope was requested and high-risk files (infra/workflow/config/deploy) are mixed in, ask for scope confirmation.

2. Guard and read scoped diffs
   - Classify the target paths. Treat as secret-path any `.env*`, `.ssh/`, `local/env.*`, `.git-credentials`, `*.http_request`, `*.http_response`, or other credential/secret-dump file:
     - Never read or print their diff content.
     - Surface their paths only and ask how to proceed (exclude, or explicit confirmation) before any enters a commit.
   - Read content for the remaining non-secret target paths so step 3 has full coverage:
     - tracked paths (`git status` rows other than `??`): `git diff --cached -- <paths>` and `git diff -- <paths>`.
     - untracked paths (`??` rows): `git diff` shows nothing for them, so read their content explicitly via `git diff --no-index /dev/null <path>` (or read the file). A new file with an innocent name but a hardcoded secret is the exact gap this closes.

3. Scan scoped diff for risky content
   - Scan all content gathered in step 2 (tracked diffs + untracked file content) for:
     - secrets/credentials (API keys, tokens, private keys, connection strings)
     - sensitive data (personal identifiers, internal-only endpoints)
     - unsuitable artifacts (debug dumps, local-only files, large generated files)
   - Mask suspicious strings; never print full secret values.
   - On any finding, stop and ask confirmation before commit.

4. Compose message
   - Run `git log --oneline -10`; follow the observed style, else Conventional Commits as `:gitmoji: <type>[scope]: <description>`.
   - English; concise imperative description.
   - If target changes are clearly unrelated, propose split commits; else one cohesive commit.

5. Stage, preview, commit
   - Before staging, check for pre-existing staged changes outside the target set (`git diff --cached --name-only` minus the target paths). If any exist, hard stop: list those paths and ask the user how to proceed (commit them first, unstage them themselves, or explicitly confirm committing them together). Never auto-reset or auto-unstage — that risks merging with worktree changes.
   - Once the index holds only target paths, stage exactly the target paths: `git add -- <paths>`.
   - Preview before committing: staged file list, shortstat, final message. Stop for confirmation only when step 3 flagged a finding or scope is ambiguous; otherwise proceed.
   - Commit normally: `git commit` (no pathspec), so pre-commit hooks run against the real, complete index. If it fails (hooks/conflicts/empty), summarize stderr and stop; do not use `--no-verify` unless explicitly requested.

## Failure Handling

- `index.lock` present: wait briefly and retry once. If it persists, do NOT auto-remove — gather evidence (active `git` process? lock age/owner), report it, and remove only after explicit user confirmation.

## Output Format

When commit succeeds, report:
- commit hash
- final commit message
- changed files count and insert/delete summary

When commit is blocked, report:
- exact blocker (safety finding, ambiguous scope, hook failure, empty commit)
- next action required from user

## Examples

- Scope isolation: user has pre-staged `fileA`, then asks "commit only `fileB`" → detect `fileA` as out-of-scope staged, stop and ask how to handle it before committing `fileB`; never silently include or auto-unstage it.
- Untracked secret: a brand-new `config.json` with a hardcoded key is in scope → its content is read via `--no-index` and scanned, so the secret is caught even though `git diff` shows nothing.
- Safety stop: token-like string found in a scoped diff → mask it, stop, ask confirmation before committing.
