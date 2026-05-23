Create a pull request for the current branch.

## Arguments

``````text
$ARGUMENTS
``````

## Workflow

1. Inspect the current branch, upstream status, changed files, and recent commits.
2. Prefer an available PR tool or MCP if one is configured for this environment.
3. If no PR tool is available, use `gh pr create` when the GitHub CLI is installed and authenticated.
4. Generate a concise, specific PR title from the branch name and commits instead of using a default title.
5. Generate a short PR body with summary and verification notes.

## Safety

- Do not push the branch unless the user explicitly asks or confirms after being told a push is required.
- Do not include secrets, local-only paths, or unrelated commit details in the PR body.
- If neither a PR tool/MCP nor `gh` is available, report the blocker and provide the title/body draft.
