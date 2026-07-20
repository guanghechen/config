# VSGit

Browse Git history and compare any two commits, branches, tags, or other commit-like references
inside VS Code.

## Browse commits

1. Open a Git repository in VS Code.
2. Open the **VSGit** Activity Bar container and expand **Commits**.
3. Expand a commit to see its directory-first file change tree.
4. Select a file to open its parent-to-commit change in VS Code's native Diff Editor.

Root commits are compared with an empty tree. Merge commits are compared with their first parent.
History is loaded in batches of 50 commits, up to 500; use **Load More Commits** to fetch the next
batch.

## Compare two commits

1. In **VSGit → Commits**, use `Cmd` (macOS) or `Ctrl` (Windows/Linux) to select exactly two commit
   rows.
2. Select **Compare Selected Commits** from the view toolbar or context menu.
3. Expand **Comparison** and select a file to open its immutable commit-to-commit diff.

VSGit uses the older selected commit as the base and the newer selected commit as the target.

## Compare arbitrary references

1. Run **VSGit: Compare References**.
2. Enter the base and target commit, branch, or tag.
3. Expand **VSGit → Comparison** and select a file.

VSGit displays changed files as a directory tree and opens file contents in VS Code's native Diff
Editor. Added, modified, deleted, copied, renamed, type-changed, unmerged, and unknown statuses are
supported.

## Architecture

`extension.ts` is only the composition root. The `app` layer owns command workflows and connects the
`view`, `history`, `compare`, and `git` layers; dependencies only point toward lower layers.
`CommitHistorySession` is the single writer for the active repository and paged commit list, while
`CompareSession` is the single writer for the active comparison. Commit file trees are loaded lazily
and cached only by the view provider. The revision content provider reads immutable commit blobs
only when VS Code opens a diff.

Invalid references, history reload failures, or Git comparison failures abort without replacing the
last successful state. A commit expansion failure is isolated to that node. Binary and oversized
blobs degrade to an explanatory virtual document.

VSGit invokes `git` with argument arrays and never through a shell. Comparing references does not
modify the target repository.
