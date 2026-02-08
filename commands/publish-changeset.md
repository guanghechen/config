Execute changeset version and publish workflow in a specified tmux pane (monorepo only).

## Arguments (Required)

``````text
$ARGUMENTS
``````

**Parse arguments as tmux pane reference:**

- `%N` (e.g., `%14`) - Global pane id: `-t %14`
- `#N` (e.g., `#3`) - Pane index N in current window: `-t :.N`
- `@M#N` (e.g., `@1#2`) - Pane index N in window @M: `-t @M.N`

If no argument is provided, ask the user to specify a tmux pane reference.

## Workflow

Execute the following steps in the specified tmux pane, waiting for each step to complete before proceeding:

### 1. Pre-flight Checks

Before starting, verify:

1. Run `git status` to ensure working directory is clean (no uncommitted changes)
2. Check for existing `.changeset/*.md` files (excluding README.md) to see if changesets exist
3. If no changesets exist, inform the user and stop

### 2. Analyze Changesets

1. Read all changeset files in `.changeset/` directory
2. Summarize which packages will be released and their bump types (major/minor/patch)
3. Show this summary to the user

### 3. Version Bump

Send command to the tmux pane:

```bash
pnpm changeset version
```

Wait for user interaction and completion. Record the packages and versions from the output for later use (commit message and git tags).

If it fails due to missing GITHUB_TOKEN, offer alternatives:

- Set GITHUB_TOKEN and retry
- Manually update version and CHANGELOG (show what changes would be made)
- Change changelog config to use `@changesets/changelog-git` instead

### 4. Review Changes

After version bump:

1. Run `git status` and `git diff` to show what changed
2. Show the updated CHANGELOG entries
3. Ask user to confirm before committing

### 5. Commit Version Bump

If user confirms:

1. Stage all changed files (package.json, CHANGELOG.md, deleted changeset files)
2. Commit with message format: `:bookmark: release: @foo/a@1.0.0, @foo/b@1.3.2` (list all released packages)
3. Push to remote

### 6. Publish

Send command to the tmux pane:

```bash
pnpm changeset publish
```

Wait for user to complete OTP verification if needed (timeout: 1 minute for OTP).

### 7. Create Git Tags

After successful publish:

1. Create git tag for each newly published package (from step 3): `<package>@<version>`
2. Push tags to remote: `git push --tags`

### 8. Summary

Report final status:

- Published packages and versions
- Git tags created
- NPM package URLs

## Notes

- Always use `tmux send-keys -t <pane_ref> '<command>' Enter` to send commands
- Use `tmux capture-pane -ep -t <pane_ref>` to check command output
- After sending commands that need user interaction, use `sleep 2 && tmux send-keys -t <pane_ref> C-m C-m` to trigger
- If any step fails, stop and report the error to the user
- Do not proceed to publish if version bump or commit fails

## Timeouts

- OTP verification: 1 minute
- No output: 10 minutes (auto-exit if no output for this duration)
