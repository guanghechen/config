# VSGit

Compare any two Git commits, branches, tags, or other commit-like references inside VS Code.

## Usage

1. Open a Git repository in VS Code.
2. Run **VSGit: Compare References**.
3. Enter the base and target references.
4. Expand **Source Control → Reference Comparison** and select a file.

VSGit displays changed files as a directory tree and opens file contents in VS Code's native Diff
Editor. Added, modified, deleted, copied, and renamed files are supported.

## Architecture

`extension.ts` is only the composition root. The `app` layer owns command workflows and connects the
`view`, `compare`, and `git` layers; dependencies only point toward lower layers. `CompareSession`
is the single writer for the active repository, resolved commits, and changed-file list. Data flows
one way through `GitClient → CompareSession → view providers`. The revision content provider reads
immutable commit blobs only when VS Code opens a diff. Invalid references or Git failures abort
without replacing the last successful comparison; binary and oversized blobs degrade to an
explanatory virtual document.

VSGit invokes `git` with argument arrays and never through a shell. Comparing references does not
modify the target repository.
