Create a git commit based on current changes. See `~/.config/codex/agents/git-committer.md` for the full commit workflow spec.

## Arguments (Optional)

```text
$ARGUMENTS
```

**If arguments are provided**, use them as context:

- **Commit scope**: File paths, glob patterns (e.g., `src/*.ts`), or descriptive filters (e.g., "only auth changes")
- **Message hints**: Additional context for generating the commit message

**If no arguments are provided**, commit all staged/unstaged changes.
