---
name: publish-changeset
description: "Execute a monorepo changeset version-and-publish release workflow inside a specified tmux pane, including pre-flight checks, build verification, package bump detection, changeset creation, versioning, review, publish, and tag push. Use when the user asks to run or assist a real release in tmux with pane refs like %N, #N, or @M#N."
---

# Publish Changeset

Run a deterministic release flow in tmux. Stop immediately on failure, report the failing step, and do not continue until the user decides.

## Required Input

Accept arguments in this format:

```text
{tmux pane ref} [scope]
```

- Parse `tmux pane ref` as required:
  - `%N` -> use with `-t %N`
  - `#N` -> use with `-t :.N`
  - `@M#N` -> use with `-t @M.N`
- Parse `scope` as optional release context:
  - bump hint: `major`, `minor`, `patch`
  - or free-text context (for example `breaking API change`, `bug fixes only`)

If no pane ref is provided, ask for it before doing anything.

## tmux Command Contract

- Send commands only via:
  - `tmux send-keys -t <pane_ref> '<command>' Enter`
- Read output only via:
  - `tmux capture-pane -ep -t <pane_ref>`
- For interaction-sensitive steps, trigger input with:
  - `sleep 2 && tmux send-keys -t <pane_ref> C-m C-m`

Wait for each step to finish before starting the next one.

## Workflow

### 1) Pre-flight checks

Run and evaluate:

- `git status` (require clean working tree)
- presence of `.changeset/*.md` excluding `.changeset/README.md`

If working tree is dirty, stop and ask user whether to clean/stash manually.

### 2) Build verification

Run:

```bash
pnpm build:production
```

If build fails, stop and report error output.

### 3) Detect packages to release (when no changeset files exist)

For each monorepo package:

1. Find latest git tag matching `<package-name>@*`
2. Detect commits touching package since latest tag
3. If no tag exists, check whether package has ever been published to npm

For every package with unreleased commits:

1. Choose bump type:
   - If `scope` contains `major|minor|patch`, use it directly
   - Otherwise infer from commit messages:
     - `feat` or `:sparkles:` -> `minor`
     - `fix` or `:bug:` -> `patch`
     - breaking marker (`!`) or `:boom:` -> `major`
     - fallback -> `patch`
2. Summarize changes from commit messages, incorporating free-text `scope` context when provided
3. Create `.changeset/<random-name>.md`:

```markdown
---
"<package-name>": <bump-type>
---

<summary>
```

4. Commit the changeset as:
   - `:bookmark: chore: add changeset for <package>@<bump-type>`
5. Keep final bump type + summary in the same changeset commit. If content must be fixed before push, amend that same commit instead of adding a follow-up content-only commit.

If no packages need release, report and stop.

### 4) Analyze changesets

Read all files under `.changeset/` and summarize package bump plan (`major|minor|patch`). Show summary to user.

### 5) Version bump

Before running versioning:

1. Snapshot old versions for all to-be-released packages

Run:

```bash
pnpm changeset version
```

After completion:

1. Record package/version results from `pnpm changeset version` output for later commit message and git tags
2. Read updated manifests to collect new versions and build release transitions for Step 6 display

Do not display transition lines yet.

If this step fails due to missing `GITHUB_TOKEN`, offer options:

1. Set `GITHUB_TOKEN` and retry
2. Manually update versions and changelog (explain expected modifications)
3. Switch changelog config to `@changesets/changelog-git`

### 6) Review changes

Run:

- `git status`
- `git diff --stat`

Show release preview with exact format. This is the first and only confirmation-facing display:

```text
<package> <old version> -> <new version>
```

- Output one package per line
- Sort by package name

Show concise changelog highlights.
Ask user confirmation before commit.

### 7) Commit version bump

If user confirms, stage release files explicitly and commit with:

- all changed `package.json` files
- all updated `CHANGELOG.md` files
- all deleted `.changeset/*.md` files

```text
:bookmark: release: @foo/a@1.0.0, @foo/b@1.3.2
```

Use real released package list in message.

### 8) Rebuild with bumped versions

Run:

```bash
pnpm build:production
```

This rebuild is mandatory. If it fails, stop and report.

### 9) Publish

Run:

```bash
pnpm changeset publish
```

Allow OTP interaction window up to 1 minute.

### 10) Create git tags and push

After successful publish:

1. Tag each published package as `<package-name>@<version>`
2. Push commit and tags:
   - `git push`
   - `git push --tags`

### 11) Final summary

Report:

- published packages and versions
- created git tags
- npm package URLs

## Timeout Rules

- OTP waiting timeout: 1 minute
- No output timeout: 10 minutes (auto-exit and report)

## Failure Handling

- Treat build/version/commit/publish failures as hard stop.
- Never continue to publish when earlier gating steps failed.
- Always provide trigger, evidence (key output), and impact in the failure report.
