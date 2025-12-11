Please create a git commit based on our current changes.

## Arguments

```text
$ARGUMENTS
```

**Interpret the arguments above as follows (in priority order):**

1. **Specific file paths**: If the arguments contain file paths or glob patterns, **only** stage and commit those files. Ignore all other changes.
2. **Scope restriction**: If the arguments explicitly describe a subset of changes to include (e.g., "only TypeScript files", "only changes related to auth"), filter the changes accordingly and only commit matching files.
3. **Commit message hints**: Otherwise, treat the arguments as contextual hints to generate a more accurate and descriptive commit message.

If no arguments are provided, commit all staged/unstaged changes as usual.

## Requirements

1. **Analyze current changes**: Run `git status` and `git diff` to understand what has been modified.
2. **Review commit history**: Run `git log --oneline -10` to understand the existing commit message style and conventions.
3. **Determine commit scope**: Based on the arguments above, decide which files to include in this commit.
4. **Write commit message** following the **Conventional Commits** specification:
   - **Format**: `<type>[optional scope]: <description>`
   - **Types** (choose the most appropriate):
     - `feat` / `feature`: A new feature
     - `fix`: A bug fix
     - `improve`: Enhancement to existing functionality
     - `refactor`: Code change that neither fixes a bug nor adds a feature
     - `doc`: Documentation only changes
     - `test`: Adding or modifying tests
     - `chore`: Maintenance tasks, dependency updates, etc.
     - `rename`: Renaming files, variables, or functions
     - `move`: Moving files or code to different locations
     - `revert`: Reverting a previous commit
   - **Scope** (optional): A noun describing the affected section in parentheses, e.g., `fix(parser):`, `feat(auth):`
   - **Description**: A concise summary in imperative mood (e.g., "add user login" not "added user login")
   - **Breaking changes**: Add `!` after type/scope for breaking changes, e.g., `feat(api)!: change response format`
   - The commit message **MUST** be written in English.
   - Use simple, clear vocabulary. Avoid overly complex words, except for technical terms which are always acceptable.
5. **Stage and commit**: Stage only the relevant files (based on scope) and create the commit.

## Notes

- If there are no changes to commit, inform the user.
- If changes include files that should not be committed (e.g., temporary files, sensitive data), ask for confirmation before proceeding.
