Create a git commit based on current changes. Prefer executing git commands directly; only pause when blocked by ambiguity, safety concerns, or required confirmation conditions.

## Arguments (Optional)

``````text
$ARGUMENTS
``````

**If arguments are provided, interpret them as follows:**

- **Commit scope**: Specify which files or changes to include in this commit.
  - File paths or glob patterns (e.g., `src/*.ts`, `lib/utils.js`)
  - Descriptive filters (e.g., "only TypeScript files", "only changes related to auth")
- **Message hints**: Additional context to help generate a more accurate commit message.

Arguments can contain scope, hints, or both. Parse them intelligently.

**If no arguments are provided**, commit all staged/unstaged changes unless the large-change guardrail requires scope confirmation.

## Workflow

Prefer executing git commands directly via tool calls. Only pause when blocked by ambiguity, safety concerns, or required confirmation conditions.

1. **Handle index.lock**: If you encounter `fatal: Unable to create '.../.git/index.lock': File exists`, retry once after a short wait (for example, 2 seconds). If it still persists, treat the lock as stale only when both conditions are true: no active git process is running for this repository, and `.git/index.lock` is older than 30 seconds. Only then delete the lock file (`rm -f .git/index.lock`) and retry.
2. **Analyze current changes**: Run `git status`, `git diff --cached`, and `git diff` to inspect staged and unstaged changes.
3. **Check for sensitive or unsuitable content**:
   - Review the collected diffs for sensitive or unsuitable content.
   - Run a pattern-based scan over the diff content (keywords and regex-style checks) using the checklist below.
   - Apply this minimum detection checklist:
     - Secrets and credentials: API keys, access tokens, passwords, private keys, certificates, connection strings.
     - High-risk patterns: `Bearer ` tokens, `AKIA`-style keys, `ghp_`/`github_pat_` tokens, JWT-like strings (`xxx.yyy.zzz`), `-----BEGIN ... PRIVATE KEY-----` blocks.
     - Sensitive data: personal identifiers, phone numbers, email lists, addresses, internal endpoints not meant for publication.
     - Unsuitable content: temporary debug dumps, local-only configs, backup files, large generated artifacts, or machine-specific files.
   - Never print full suspected secrets or personal data; always mask sensitive values in reports.
   - If any findings exist, stop and ask for confirmation before commit. Use this report format: `<file path> | <masked evidence> | <reason> | <suggested action>`.
4. **Review commit history**: Run `git log --oneline -10` to understand the existing commit message style and conventions.
5. **Determine commit scope**: Based on the arguments above, decide which files to include in this commit.
6. **Apply large-change guardrail**: If no explicit commit scope is provided and the change set is large (for example, more than 20 files) or touches high-risk paths (for example, deployment/infrastructure/workflow/configuration files), pause and ask for scope confirmation before staging.
7. **Decide whether to split commits**:
   - **DO NOT ask** if the changes are logically cohesive (single feature, single fix, single refactor, etc.)
   - **Only ask** if the changes are clearly unrelated (e.g., a bug fix mixed with an unrelated new feature)
   - When in doubt, **proceed with a single commit** — do not ask.
8. **Write commit message** following **Conventional Commits** with **Gitmoji** prefix:
   - **Format**: `:gitmoji: <type>[optional scope]: <description>`
   - Prefer standard Conventional Commit types (`feat`, `fix`, `docs`, `refactor`, `style`, `test`, `chore`, `build`, `ci`, `perf`, `revert`).
   - Use custom types (`improve`, `move`, `rename`, `wip`) only if the repository explicitly uses them.
   - Choose type and Gitmoji from the **Gitmoji and Type Reference** section below.
   - **Scope** (optional): A noun describing the affected section in parentheses, e.g., `:bug: fix(parser):`, `:sparkles: feat(auth):`
   - **Description**: A concise summary in imperative mood (e.g., "add user login" not "added user login")
   - **Breaking changes**: Append exclamation mark after type/scope, e.g., `:boom: feat(api)!: change response format`
   - The commit message **MUST** be written in English.
   - Use simple, clear vocabulary. Avoid overly complex words, except for technical terms which are always acceptable.
9. **Stage changes**: Stage only the relevant files (based on scope).
10. **Preview commit summary**: Before commit, always present staged files, staged shortstat, and the final commit message.
11. **Create commit**: Create the commit after the preview step.
12. **Handle commit failures**: If commit creation fails (for example, hooks, conflicts, empty commit, or command errors), present a concise stderr summary and stop. Do not bypass hooks (for example, `--no-verify`) or force an empty commit unless explicitly requested by the user.

## Gitmoji and Type Reference

Use this reference to choose `<type>` and `:gitmoji:` for the commit message header.

### Type and Gitmoji Mapping

This table includes both standard and optional repository-specific types.

| Type       | Gitmoji                   | Description                             |
|------------|---------------------------|-----------------------------------------|
| `chore`    | `:alien:`                 | Update code due to external API changes |
| `chore`    | `:arrow_down:`            | Downgrade dependencies                  |
| `chore`    | `:arrow_up:`              | Upgrade dependencies                    |
| `chore`    | `:bento:`                 | Add or update assets                    |
| `chore`    | `:coffin:`                | Remove dead code                        |
| `chore`    | `:fire:`                  | Remove code or files                    |
| `chore`    | `:heavy_minus_sign:`      | Remove a dependency                     |
| `chore`    | `:heavy_plus_sign:`       | Add a dependency                        |
| `chore`    | `:pushpin:`               | Pin dependencies to specific versions   |
| `chore`    | `:see_no_evil:`           | Add or update .gitignore                |
| `chore`    | `:wrench:`                | Configuration changes                   |
| `docs`     | `:memo:`                  | Documentation changes                   |
| `feat`     | `:bento:`                 | Add or update assets                    |
| `feat`     | `:label:`                 | Release or mentionable changes          |
| `feat`     | `:sparkles:`              | A new feature                           |
| `fix`      | `:alien:`                 | Update code due to external API changes |
| `fix`      | `:ambulance:`             | Critical hotfix                         |
| `fix`      | `:bug:`                   | A bug fix                               |
| `improve`  | `:alien:`                 | Update code due to external API changes |
| `improve`  | `:art:`                   | Improve structure/format of code        |
| `improve`  | `:bento:`                 | Add or update assets                    |
| `improve`  | `:coffin:`                | Remove dead code                        |
| `improve`  | `:fire:`                  | Remove code or files                    |
| `improve`  | `:zap:`                   | Performance improvement                 |
| `move`     | `:truck:`                 | Move files/resources                    |
| `refactor` | `:coffin:`                | Remove dead code                        |
| `refactor` | `:fire:`                  | Remove code or files                    |
| `refactor` | `:recycle:`               | Refactor code                           |
| `rename`   | `:truck:`                 | Rename files/resources                  |
| `revert`   | `:rewind:`                | Revert changes                          |
| `style`    | `:fire:`                  | Remove code or files                    |
| `style`    | `:lipstick:`              | UI and style updates                    |
| `test`     | `:white_check_mark:`      | Add or update tests                     |
| `wip`      | `:beers:`                 | Temporary save, incomplete work         |
| `wip`      | `:poop:`                  | Temporary save, incomplete work         |

### Additional Gitmoji Modifiers (Not Commit Types)

| Gitmoji                   | Description           |
|---------------------------|-----------------------|
| `:boom:`                  | Breaking changes      |
| `:building_construction:` | Architectural changes |
| `:construction:`          | Work in progress      |
| `:lock:`                  | Fix security issues   |
| `:pencil2:`               | Fix typos             |

## Notes

- If there are no changes to commit, inform the user.
- You may ask scope questions only in these cases: large-change guardrail trigger, or clearly unrelated changes that may need split commits.
- Confirmation to proceed with commit is required only when sensitive or unsuitable content is detected.
- The preview step is informational and does not require extra confirmation by default.
