# VSGit

Search Git history, browse commits, and compare any two commits, branches, tags, or other
commit-like references inside VS Code.

## Browse commits

1. Open a Git repository in VS Code.
2. Open the **VSGit** Activity Bar container and expand **Commits**.
3. Expand a commit to see its directory-first file change tree.
4. Select a file to open its parent-to-commit change in VS Code's native Diff Editor.

Root commits are compared with an empty tree. Merge commits are compared with their first parent.
History is loaded in batches of 50 commits, up to 500; use **Load More Commits** to fetch the next
batch.

## Search commits

1. Open **VSGit → History Search** in the sidebar.
2. Enter a commit-message pattern and configure any advanced filters.
3. Select **Search**; matching commits appear in the native **Commits** tree below.

The **Search Commits** toolbar and Command Palette action remain available as a QuickPick fallback.

Search supports these filters:

- Scope: commits reachable from `HEAD`, all refs, or one custom revision/range such as
  `main..feature`.
- Path: one file, directory, or Git pathspec such as `:(glob)src/**/*.ts`.
- Author, since date, until date, and commit-message regex.
- Exact content occurrence changes with `git log -S`.
- Added or removed lines matching a regex with `git log -G`.

Filters use AND semantics. The `-S` and `-G` content modes are mutually exclusive. Expanding a
matching commit shows its complete change tree so surrounding changes remain visible. Path filters
use Git pathspec semantics and do not automatically follow historical names across renames.

Refresh and **Load More Commits** preserve the current search. Select **Clear** in **History
Search** or run **Clear Commit Search** to return to normal `HEAD` history. Search failures keep
both the sidebar draft and the last successful result set.

## Compare two commits

Use either workflow in **VSGit → Commits**:

- Right-click two commits and select **Mark for Comparison**, then select **Compare Marked Commits**
  from the view toolbar or context menu.
- Mark one commit, then right-click another and select **Compare with Marked Commit** to compare
  immediately while keeping the original mark.

Marked commits use a bookmark icon. Use **Unmark Commit** or **Clear Comparison Marks** to remove
marks.

To compare a historical commit with the repository's current `HEAD`, right-click it and select
**Compare Commit with HEAD**.

After starting a comparison:

1. Expand **Comparison**.
2. Select a file to open its immutable commit-to-commit diff.

VSGit uses the older marked commit as the base and the newer commit as the target. **Compare Commit
with HEAD** always uses the selected commit as the base and `HEAD` as the target.

## Compare arbitrary references

1. Run **VSGit: Compare References**.
2. Enter the base and target commit, branch, or tag.
3. Expand **VSGit → Comparison** and select a file.

VSGit displays changed files as a directory tree and opens file contents in VS Code's native Diff
Editor. Added, modified, deleted, copied, renamed, type-changed, unmerged, and unknown statuses are
supported.

## Architecture

`extension.ts` is only the composition root. The `app` layer groups comparison and commit-history
workflows into focused controllers. The `view` layer is organized by comparison, history, diff, and
shared file-change concerns; extension command, context, view, and item IDs live in `platform`.
Dependencies only point toward lower layers, and automated architecture tests reject reverse edges
and import cycles.

The **History Search** Webview owns only its unsubmitted draft. Validated messages flow through the
search controller into `CommitHistorySession`, which remains the single writer for the active
repository, browse/search mode, applied query, and paged commit list. `CommitMarkSession` is the
single writer for comparison marks, and `ComparisonSession` is the single writer for the active
comparison. `CommitChangeCache` owns a bounded cache of derived immutable commit changes. Commit
file trees are loaded lazily, and the revision content provider reads immutable commit blobs only
when VS Code opens a diff.

Superseded history and comparison operations abort their in-flight Git processes. Comparisons
started from known commits skip redundant reference resolution, commit-change cache entries survive
history refreshes, and repository candidates are deduplicated and resolved concurrently.

Invalid references, history reload failures, or Git comparison failures abort without replacing the
last successful state. A commit expansion failure is isolated to that node. Binary and oversized
blobs degrade to an explanatory virtual document. Git processes have a 15-second timeout; superseded
operations and cancelled searches are aborted, while failed cache entries are removed so the next
expansion can retry. Sidebar requests have isolated cancellation scopes, malformed Webview messages
abort at the extension boundary, and applied, cancelled, and unavailable outcomes remain distinct.
Custom revisions are placed after `--end-of-options`, and paths are placed after `--`.

VSGit invokes `git` with argument arrays and never through a shell. Comparing references does not
modify the target repository.

Development conventions and verification commands are documented in
[CONTRIBUTING.md](CONTRIBUTING.md).
