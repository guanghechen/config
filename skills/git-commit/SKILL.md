---
name: git-commit
description: Create safe, convention-aligned git commits from current changes. Use when the user asks to commit, asks for a commit message, asks to commit only part of changes, or asks to follow existing repo commit conventions.
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

1. Check repository state
- Run `git status`, `git diff --cached`, and `git diff`.
- If there are no staged or unstaged changes in the requested scope, report and stop.

2. Handle `index.lock` safely
- If commit/stage fails with `index.lock`, wait briefly and retry once.
- If lock persists: verify no active `git` process and lock age > 30s, then remove lock and retry.

3. Scan changes for risky content
- Scan staged+unstaged diff content for:
  - secrets/credentials (API keys, tokens, private keys, connection strings)
  - sensitive data (personal identifiers, internal-only endpoints)
  - unsuitable artifacts (debug dumps, local-only files, large generated files)
- Never print full secret values; always mask suspicious strings.
- If any finding exists, stop and ask user confirmation before commit.

4. Learn local commit convention
- Run `git log --oneline -10`.
- Follow the observed local style. If no clear style exists, default to Conventional Commits.

5. Decide commit scope
- If user provided scope, stage only that scope.
- If no scope and high-risk files are mixed in (infra/workflow/config/deploy), ask for scope confirmation.
- If changes are clearly unrelated, propose split commits; otherwise prefer one cohesive commit.

6. Compose commit message
- Default format when repo uses it: `:gitmoji: <type>[optional scope]: <description>`.
- Message language: English.
- Description style: concise imperative phrase.

7. Stage and preview
- Stage selected files.
- Show a preview before commit:
  - staged file list
  - staged shortstat
  - final commit message

8. Create commit
- Run commit after preview.
- If commit fails (hooks/conflicts/empty commit), summarize stderr and stop.
- Do not bypass hooks with `--no-verify` unless explicitly requested.

## Output Format

When commit succeeds, report:
- commit hash
- final commit message
- changed files count and insert/delete summary

When commit is blocked, report:
- exact blocker (safety finding, ambiguous scope, hook failure, empty commit)
- next action required from user

## Examples

Example 1 (full commit):
- User: "commit current changes"
- Action: analyze all diffs, infer convention, preview, commit.

Example 2 (scoped commit):
- User: "commit only `.gitignore` changes"
- Action: stage only `.gitignore`, generate scoped message, preview, commit.

Example 3 (safety stop):
- User: "commit everything"
- Action: detect token-like string in diff, mask evidence, ask confirmation before continuing.
