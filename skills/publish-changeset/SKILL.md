---
name: publish-changeset
description: "Execute a monorepo changeset version-and-publish release workflow inside a specified tmux pane, including pre-flight checks, build verification, package bump detection, changeset creation, versioning, review, publish, and exact tag push. Use when the user asks to run or assist a real release in tmux with pane refs like %N, #N, or @M#N."
---

# Publish Changeset

Run a deterministic release flow in tmux. On any failure, stop at once, report the failing step, and wait for the user to decide.

## Required Input

Accept arguments in this format:

```text
{tmux pane ref} [scope]
```

- `tmux pane ref` (required) — the target pane for the whole release flow.
- `scope` (optional release context):
  - bump hint: `major`, `minor`, `patch`
  - or free-text context (for example `breaking API change`, `bug fixes only`)

If no pane ref is given, ask for it before doing anything.

## tmux Command Contract

Release-specific submission rules for driving the target pane:

- Send a shell command only once the target pane is confirmed to be an idle shell prompt:
  - `tmux send-keys -t <pane_ref> '<command>' Enter`
- For interaction-sensitive steps, capture first, identify the exact prompt state, then send only the single expected key or value.
- Never submit with a fixed sleep such as `sleep 2 && ...`, and never send a blind double-Enter.

Let each step finish before starting the next.

## Workflow

The flow has three confirmation gates (Steps 4, 6, 9). Each gate authorizes only the steps up to the next gate, never beyond it.

### Step 1 — Pre-flight checks

- Verify, in order:
  - `git status` — the tree must be clean, except that uncommitted `.changeset/*.md` files are allowed (a manually prepared changeset)
  - `git branch --show-current` — branch is non-empty; record it as the release branch for Step 10
- Detect `.changeset/*.md` (excluding `.changeset/README.md`): if present, Step 3 is skipped and these drive the release; if absent, Step 3 generates them.
- Stop when:
  - any non-changeset path is uncommitted → ask whether to clean/stash manually
  - branch is detached or unknown → ask for the branch/ref to push

### Step 2 — Build verification

Run:

```bash
pnpm build:production
```

If the build fails, stop and report the error output.

### Step 3 — Detect packages and generate changesets

Runs only when no changeset file exists. Prepare the generated changesets **in memory** — never write or commit before the user confirms.

1. **Scan** each package for unreleased work:
   - latest git tag matching `<package-name>@*`
   - commits touching the package since that tag
   - if no tag exists, whether the package was ever published to npm
2. **Build** a changeset for each package that has unreleased commits:
   - **bump type** — use `scope` if it names `major|minor|patch`; otherwise infer from commits:
     - `feat` / `:sparkles:` → `minor`
     - `fix` / `:bug:` → `patch`
     - breaking (`!`) / `:boom:` → `major`
     - fallback → `patch`
   - **summary** — from commit messages, folding in free-text `scope` when given

Each generated changeset takes this exact shape:

```markdown
---
"<package-name>": <bump-type>
---

<summary>
```

If no package needs release, report and stop.

### Step 4 — Analyze release plan and confirm

Merge existing `.changeset/*.md` files with any changesets generated in Step 3, then present the plan **before** writing any generated changeset or running versioning.

The plan lists:

- the bump per package (`major|minor|patch`)
- the source of each bump: an existing changeset file, or a generated changeset
- the full content of every generated changeset (package, bump, summary)

**Gate** — confirming the plan authorizes **Step 5 only**: writing the generated changesets, committing them, and running `pnpm changeset version`. Then stop for the Step 6 review; the version-bump commit, the rebuild, and the npm publish each have a later gate of their own. If the user rejects or edits, revise the plan or stop.

### Step 5 — Materialize changesets and run versioning

1. **Materialize** — only if Step 3 generated changesets; otherwise skip to versioning:
   - write each generated changeset as `.changeset/<random-name>.md`
   - commit only those files: `:bookmark: chore: add changeset for <package>@<bump-type>`
   - if its content needs fixing while the commit is still local, amend that changeset commit rather than adding a content-only follow-up
   - a pre-existing changeset (including an uncommitted manual one from Step 1) is left as-is here; Step 7 consumes it into the release commit
2. **Version** the release:
   - snapshot old versions of all to-be-released packages
   - run `pnpm changeset version`
   - record the package/version results for the later commit message and tags
   - read the updated manifests to build the Step 6 transitions, but do not show them until Step 6

If versioning fails on a missing `GITHUB_TOKEN`, offer to:

- set `GITHUB_TOKEN` and retry
- update versions and changelog by hand (explain the expected edits)
- switch changelog config to `@changesets/changelog-git`

### Step 6 — Review versioned changes

1. run `git status` and `git diff --stat`
2. show the release preview — one package per line, sorted by name:

   ```text
   <package> <old version> -> <new version>
   ```

3. add concise changelog highlights

**Gate** — confirming authorizes:

- **Step 7** — commit the version bump
- **Step 8** — rebuild with bumped versions

Then stop for the Step 9 publish gate.

### Step 7 — Commit version bump

Stage the release files explicitly:

- every changed `package.json`
- every updated `CHANGELOG.md`
- every deleted `.changeset/*.md`

Commit with the real released-package list:

```text
:bookmark: release: @foo/a@1.0.0, @foo/b@1.3.2
```

### Step 8 — Rebuild with bumped versions

Run:

```bash
pnpm build:production
```

This rebuild is mandatory. If it fails, stop and report.

### Step 9 — Confirm and publish to npm

Just before publishing, ask for explicit confirmation listing the exact packages and versions:

```text
Confirm publish to npm (irreversible):
<package> <new version>
```

**Gate** — confirming authorizes:

- **publish** — run `pnpm changeset publish`
- **Step 10** — tag and push, as the natural completion of the publish

Allow up to 1 minute for OTP. For any OTP or confirmation prompt, capture the pane first, verify it, then send the input once.

### Step 10 — Tag and push exact refs

After a successful publish:

1. tag each published package as `<package-name>@<version>`
2. push the release commit to the branch recorded in Step 1: `git push origin HEAD:<branch>`
3. push only this run's tags: `git push origin <tag1> <tag2>`

Never use `git push --tags`.

### Step 11 — Final summary

Report:

- published packages and versions
- created git tags
- npm package URLs

## Timeout Rules

- OTP wait: 1 minute
- No output: 10 minutes (auto-exit and report)

## Failure Handling

- Treat any build/version/commit/publish failure as a hard stop.
- Never publish when an earlier gating step failed.
- Always report trigger, evidence (key output), and impact.
