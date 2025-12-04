Please create a git commit based on our current changes.

## Optional Hints

If provided, use the following hints to help generate a more accurate commit message:

```text
$ARGUMENTS
```

## Requirements

1. **Analyze current changes**: Run `git status` and `git diff` to understand what has been modified.
2. **Review commit history**: Run `git log --oneline -10` to understand the existing commit message style and conventions.
3. **Write commit message**:
   - Follow the style and conventions of previous commits in this repository.
   - Summarize the changes concisely and accurately.
   - If hints are provided above, incorporate them to make the commit message more descriptive.
   - The commit message **MUST** be written in English.
   - Use simple, clear vocabulary. Avoid overly complex words, except for technical terms which are always acceptable.
4. **Stage and commit**: Stage all relevant changes and create the commit.

## Notes

- If there are no changes to commit, inform the user.
- If changes include files that should not be committed (e.g., temporary files, sensitive data), ask for confirmation before proceeding.
