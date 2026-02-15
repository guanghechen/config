Execute changeset version and publish workflow in a specified tmux pane (monorepo only).

## Arguments

``````text
$ARGUMENTS
``````

**Format:** `{tmux pane ref} [scope]`

- **tmux pane ref** (required): Target pane for executing commands
  - `%N` (e.g., `%14`) - Global pane id: `-t %14`
  - `#N` (e.g., `#3`) - Pane index N in current window: `-t :.N`
  - `@M#N` (e.g., `@1#2`) - Pane index N in window @M: `-t @M.N`
- **scope** (optional): Additional context for changeset generation
  - Bump level hint: `minor`, `patch`, `major`
  - Or any extra info to help determine changes (e.g., "breaking API change", "bug fixes only")

If no argument is provided, ask the user to specify a tmux pane reference.

## Workflow

Execute the following steps in the specified tmux pane, waiting for each step to complete before proceeding:

### 1. Pre-flight Checks

Before starting, verify:

1. Run `git status` to ensure working directory is clean (no uncommitted changes)
2. Check for existing `.changeset/*.md` files (excluding README.md) to see if changesets exist

### 2. Build Verification

Execute production build to ensure all packages compile successfully:

```bash
pnpm build:production
```

If build fails, stop and report the error to the user. Do not proceed with release if build fails.

### 3. Detect Packages to Release

If no changeset files exist, automatically detect packages that need release:

1. **Find unreleased commits**: For each package in the monorepo:
   - Get the latest git tag matching `<package-name>@*` pattern
   - Check if there are commits affecting that package since the tag
   - If no tag exists, check if package has ever been published to npm
2. **Analyze changes**: For each package with unreleased commits:
   - If **scope** argument specifies a bump level (`major`/`minor`/`patch`), use that
   - Otherwise, read commit messages to determine bump type:
     - `feat` / `:sparkles:` -> minor
     - `fix` / `:bug:` -> patch
     - breaking change marker (exclamation mark in conventional commit) / `:boom:` -> major
     - Default to patch if unclear
   - Generate a summary of changes from commit messages
   - If **scope** argument contains extra context, incorporate it into the summary
3. **Create changeset file**: Write `.changeset/<random-name>.md` with:
   ```markdown
   ---
   "<package-name>": <bump-type>
   ---

   <summary of changes>
   ```
4. **Commit the changeset**: Stage and commit with message `:bookmark: chore: add changeset for <package>@<bump-type>`
5. If no packages need release, inform the user and stop

### 4. Analyze Changesets

1. Read all changeset files in `.changeset/` directory
2. Summarize which packages will be released and their bump types (major/minor/patch)
3. Show this summary to the user

### 5. Version Bump

Send command to the tmux pane:

```bash
pnpm changeset version
```

Wait for completion. Record the packages and versions from the output for later use (commit message and git tags).

If it fails due to missing GITHUB_TOKEN, offer alternatives:

- Set GITHUB_TOKEN and retry
- Manually update version and CHANGELOG (show what changes would be made)
- Change changelog config to use `@changesets/changelog-git` instead

### 6. Review Changes

After version bump:

1. Run `git status` and `git diff --stat` to show what changed
2. Show the updated CHANGELOG entries briefly
3. Ask user to confirm before committing

### 7. Commit Version Bump

If user confirms:

1. Stage all changed files (package.json, CHANGELOG.md, deleted changeset files)
2. Commit with message format: `:bookmark: release: @foo/a@1.0.0, @foo/b@1.3.2` (list all released packages)

### 8. Publish

Send command to the tmux pane:

```bash
pnpm changeset publish
```

Wait for user to complete OTP verification if needed (timeout: 1 minute for OTP).

### 9. Create Git Tags & Push

After successful publish:

1. Create git tag for each newly published package (from step 5): `<package-name>@<version>`
2. Push commits and tags to remote: `git push && git push --tags`

### 10. Summary

Report final status:

- Published packages and versions
- Git tags created
- NPM package URLs

## Notes

- Always use `tmux send-keys -t <pane_ref> '<command>' Enter` to send commands
- Use `tmux capture-pane -ep -t <pane_ref>` to check command output
- After sending commands that need user interaction, use `sleep 2 && tmux send-keys -t <pane_ref> C-m C-m` to trigger
- If any step fails, stop and report the error to the user
- Do not proceed to publish if version bump fails or commit fails

## Timeouts

- OTP verification: 1 minute
- No output: 10 minutes (auto-exit if no output for this duration)
