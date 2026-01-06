Create a git commit based on current changes. Prefer executing git commands directly; only pause to ask if you have questions or concerns.

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

**If no arguments are provided**, commit all staged/unstaged changes.

## Workflow

Prefer executing git commands directly via tool calls. Only pause to ask if you encounter ambiguity or concerns.

1. **Handle index.lock**: If you encounter `fatal: Unable to create '.../.git/index.lock': File exists`, automatically delete the lock file (`rm -f .git/index.lock`) and retry.
2. **Analyze current changes**: Run `git status` and `git diff` to understand what has been modified.
3. **Review commit history**: Run `git log --oneline -10` to understand the existing commit message style and conventions.
4. **Determine commit scope**: Based on the arguments above, decide which files to include in this commit.
5. **Decide whether to split commits**:
   - **DO NOT ask** if the changes are logically cohesive (single feature, single fix, single refactor, etc.)
   - **Only ask** if the changes are clearly unrelated (e.g., a bug fix mixed with an unrelated new feature)
   - When in doubt, **proceed with a single commit** — do not ask.
6. **Write commit message** following **Conventional Commits** with **Gitmoji** prefix:
   - **Format**: `:gitmoji: <type>[optional scope]: <description>`
   - **Types and Gitmoji mapping** (choose the most appropriate):
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
     | `doc`      | `:memo:`                  | Documentation changes                   |
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
     | -          | `:boom:`                  | Breaking changes                        |
     | -          | `:building_construction:` | Architectural changes                   |
     | -          | `:construction:`          | Work in progress                        |
     | -          | `:lock:`                  | Fix security issues                     |
     | -          | `:pencil2:`               | Fix typos                               |
   - **Scope** (optional): A noun describing the affected section in parentheses, e.g., `:bug: fix(parser):`, `:sparkles: feat(auth):`
   - **Description**: A concise summary in imperative mood (e.g., "add user login" not "added user login")
   - **Breaking changes**: Append exclamation mark after type/scope, e.g., `:boom: feat(api)!: change response format`
   - The commit message **MUST** be written in English.
   - Use simple, clear vocabulary. Avoid overly complex words, except for technical terms which are always acceptable.
7. **Stage and commit**: Stage only the relevant files (based on scope) and create the commit.

## Notes

- If there are no changes to commit, inform the user.
- If changes include files that should not be committed (e.g., temporary files, sensitive data), ask for confirmation before proceeding.
- **Do not ask for confirmation** before creating the commit unless one of the above exceptions applies.

