## Overview
- Deliver a native file explorer that reuses our `std.collection.Filetree` infrastructure but exposes its own widget-driven UX instead of leaning on the picker/searcher stacks.
- Operates against the current working directory by default while allowing future multi-root sessions (workspace root, project roots discovered by LSP) without reinitialising UI state.
- Responds to filesystem and git status changes in near real time so the tree always reflects staged/unstaged state, additions, removals, and renames with minimal manual refreshes.

## Goals & Scope
- Implement a side-panel style explorer under `lua/eve/ux/widget/explorer/` with the shared widget API (`focus`, `toggle`, `hide`, `isvisible`, `isfocused`).
- Keep the widget docked to the leftmost column with a Snacks.nvim-inspired two-window layout (prompt on top, tree below) so it behaves like a traditional file sidebar rather than a float.
- Adopt Snacks’ sidebar sizing defaults (`width = 40`, `min_width = 40`, no preview pane) while exposing them through our settings overrides so teams can tune the sidebar width consistently.
- Watch the root directory via libuv (`vim.uv.new_fs_event`) and extend watchers to expanded subdirectories so inserts, deletes, moves, and chmod mutations are propagated lazily.
- Track git metadata for every visible node (staged vs unstaged badges) by leaning on `eve.state.git.resolve_status` rather than reimplementing porcelain parsing.
- Avoid exhaustive `collect_files` scans; instead, call `rstd.fs.readdir` on demand per directory and cache the result until dirty markers indicate a refresh is needed.
- Always surface hidden and ignored files on expansion; filtering is handled in the UI rather than the filesystem layer so the explorer mirrors the on-disk hierarchy.
- Keep the design modular so tree rendering, state management, and command wiring can evolve independently.

## UX Outline
- Default presentation is a fixed-width stack of **normal** windows docked on the extreme left of the current tabpage. The explorer owns a vertical split constrained to `explorer.width` (default 40 cols), marks every window inside it `winfixwidth = true`, and preserves the layout across buffers and tabs.
- The split contains two vertically-stacked windows in the Snacks.nvim style: a single-line input window on top (prompt, filter, breadcrumbs) and a scrollable result tree on the bottom.
- The input window exposes command hints, fuzzy filter text, and quick toggles (hidden files, git-only, root selector). It mirrors state between the textfield and `IExplorerInputState` observable so external actions can edit the prompt without stealing focus.
- Window resizing keeps the stack pinned left: user-driven `:vertical resize` updates `explorer.width`, while the input window clamps its height to one row (plus optional winbar) and the tree window fills the remainder.
- Renders a hierarchical tree with file and folder icons from `std.fileicon`, git badges appended to the right, and highlight groups pulled from `eve.constant.hlgroup`.
- Navigation mirrors our picker/searcher conventions: `<Enter>`/`l` open or expand, `<Backspace>`/`h` collapse or ascend, `<Tab>` toggles selection, `.` re-root on node, `oa`/`oA` forward to AI helpers, and we reuse existing `<leader>` bindings for visibility toggles and destructive actions. Git stage/unstage flows stay wired to the existing git action commands rather than new explorer-specific keys.
- Supports multi-select via `m` to mark nodes and exposes batch actions (open, stage, yank paths). All keymaps flow through `eve.command.definitions` so they can be rebound centrally.
- The widget cooperates with `eve.ux.nvimbar` to display breadcrumbs or quick filters when the window width permits.

### Shortcut Reference
| Keys                | Modes    | Action                                     | Notes 
|---------------------|----------|--------------------------------------------|------------------------------------------------------|
| `<Enter>`, `l`      | i / n / v| Open file or expand directory              | Same action routing as picker filetree `open_node` |
| `<Backspace>`, `h`  | i / n / v| Collapse directory / attach parent         | Calls `attach_parent` + `toggle_node` as in picker |
| `.`                 | i / n / v| Re-root explorer at node                   | Mirrors picker `attach_node` |
| `<Tab>`             | i / n / v| Toggle selection                           | Keeps multi-select parity with picker/searcher |
| `[i` / `]i`         | i / n / v| Jump to parent / last child line           | Navigation helpers from picker treeview |
| `oi`, `a`           | i / n / v| Create file or directory                   | Prompts for type, reuses `create_node` |
| `od`, `d`           | i / n / v| Delete node                                | Respects trash configuration, calls `remove_node` |
| `or`, `r`           | i / n / v| Rename node                                | Delegates to `rename_node` |
| `om`                | i / n / v| Move node                                  | Opens move prompt via existing action |
| `oc`                | i / n / v| Copy absolute path                         | Feeds into clipboard / command palette |
| `oa` / `oA`         | i / n / v| Send node / subtree to AI                  | Shares automation with picker AI hooks |
| `<leader>dd`        | i / n / v| Hide node temporarily                      | Uses visibility flagging already in picker |
| `<leader>D`         | i / n / v| Hide subtree temporarily                   | Same as above but recursive |
| `m`                 | n / v    | Mark node for batch operation              | Writes to explorer selection state |
| `<C-q>`             | i / n / v| Send selection to quickfix                 | Provided by common picker keymap |

## Data Model
### Node Metadata
- `IExplorerNodeMeta` augments `std.collection.filetree.INode` with explorer-specific state: `filepath`, `filetype`, `loaded` (children already fetched), `expanded`, `watcher_stop` (function|nil), `git_display`, `git_highlight`, `stat` (size, mtime), and `depth`.
- `IExplorerPendingMutation` tracks queued filesystem events (`kind`, `target`, `source`, `is_directory`, `timestamp`).
- `IExplorerSelectionState` stores the focused UUID, the last opened buffer, and a set of marked nodes.
- `IExplorerInputState` holds the prompt text, cursor column, active filter tokens, and toggle flags (show_hidden, git_only, regex, case_sensitive).

### Tree Store
- Backed by a dedicated `std.collection.Filetree` instance scoped to the explorer widget; the root UUID corresponds to the normalised root path (cwd by default).
- Maintains `IExplorerNodeIndex` (filepath → UUID, UUID → metadata) so readdir results, git updates, and watcher events can resolve nodes without scanning the full tree.
- Exposes observables: `o_rootpath`, `o_selection`, `o_marked`, `o_tree_dirty`, allowing other layers (widget, commands) to subscribe without internal coupling.

## State Layer (`lua/eve/state/explorer.lua`)
- Owns the explorer store lifecycle. Provides `bootstrap(rootpath)`, `set_root(path)`, `expand(uuid, opts)`, `collapse(uuid)`, `refresh(uuid, opts)`, `mark(uuid, enabled)`, `open(uuid, open_opts)`.
- Mirrors Snacks defaults by enabling `watch = true`, `follow_file = true`, `git_status = true`, `git_untracked = true`, and `diagnostics = true` out of the box; overrides flow through observables so integrations can opt out.
- Wraps `rstd.fs.readdir` to fetch `(IExplorerEntry[])` where each entry contains type, name, absolute path, permissions, size, owner/group, timestamps, and precomputed icon data.
- Persists expansion state per root inside `std.path.locate_workspace_filepath("explorer/state.json")` using `std.fs.write_json` so sessions survive restart; collapse is opt-in to avoid throttling disk writes.
- Integrates with `std.collection.Dirtier` to coalesce rapid watcher events and with `std.collection.Scheduler` to defer heavy re-indexing to the main loop.
- Publishes a `dispose()` hook to teardown watchers and clear caches when the widget closes or the root path changes.

## Directory Watching & Refresh Strategy
- Extend `std.fs.watch_file` (or add `std.fs.watch_directory`) so directories are watched with `{ watch_entry = true, recursive = false }` to pick up renames and in-place edits.
- The root directory is always watched; subdirectory watchers are attached on `expand` and removed on `collapse` or node eviction. `watcher_stop` closures are stored inside `IExplorerNodeMeta`.
- Watch callbacks normalise absolute paths, push an `IExplorerPendingMutation` into a debounce queue, and schedule a refresh of the affected node using `std.timer.debounce` (~120 ms).
- Event consolidation rules:
  - `rename` events carrying both old and new paths produce a single `move` mutation.
  - `delete` on a directory marks the subtree as dirty and recursively clears watchers.
  - `change` events trigger metadata refresh (size, mtime) without reissuing a full `readdir` unless the node is a directory.
- Manual `refresh` command flushes outstanding mutations and forces a readdir even if the debounce queue is empty.

## Git Status Integration
- Subscribe to `eve.state.git.refresh` notifications via a lightweight dirtier (`eve.status.dirtier_explorer_git`). Whenever git cache refreshes, iterate the visible UUIDs and update `git_display` / `git_highlight` using `eve.state.git.resolve_status(filepath, filetype)`.
- Directory badges mirror the aggregate display returned by `resolve_status(..., "directory")` so expanded folders reflect nested staged content.
- Provide helper `IExplorerGitSnapshot { display, highlight, staged_bits, unstaged_bits }` so the renderer can align staging columns without recomputing per draw.
- Expose actions to stage/unstage files by calling into existing git action modules (`fml/action/git/stage.lua`) instead of shelling out directly.

## Widget Layer (`lua/eve/ux/widget/explorer/`)
- `init.lua` exports `Explorer = require(".../explorer")` and registers the module in `lua/eve/ux/widget/init.lua`.
- Core files:
-  - `layout.lua`: reserves the leftmost column, creates the vertical split + stacked windows, tracks original window focus, and restores layout on `hide`.
-  - `explorer.lua`: orchestrates the widget API, state subscriptions, and delegates to layout/input/tree renderers.
-  - `input.lua`: wires a prompt-style buffer (`buftype = "prompt"`, `filetype = "eve-explorer-input"`) to the input state observable, handles insert-mode shortcuts, and surfaces quick toggles.
-  - `tree.lua` (or `render.lua`): consumes the tree snapshot plus highlights, writes buffer lines, and installs extmarks; leverages `eve.ux.picker.view.filetree` for indentation guides and virtualization.
-  - `keymap.lua`: installs buffer-local mappings that route into `fml.action.explorer`.
-  - `statusline.lua` or `winbar.lua`: renders breadcrumbs, filter indicators, and git summary in the tree window bar.
- Tree buffer uses `filetype = "eve-explorer"`, `modifiable = false`, `bufhidden = "hide"`, `swapfile = false`. Highlights rely on `vim.hl.range` (no deprecated APIs). Input buffer keeps `modifiable = true` but disables `swapfile` and sets `nowrap`.
- Selection changes emit cursor movement to keep the tree and buffer aligned; collapsed nodes remove their children from rendered lines without touching the underlying filetree store.

## Actions & Command Surface (`lua/fml/action/explorer/*.lua`)
- Introduce an action module that lazily instantiates the explorer widget, mirroring the Notepad/Terminal pattern (`toggle.lua`, `focus.lua`, `open.lua`, `mark.lua`, `git.lua`).
- Commands live under `eve.command.definitions.explorer` (e.g., `Fexplorertoggle`, `Fexplorerfocus`, `Fexplorerrefresh`, `Fexplorercreatefile`, `Fexplorercreatedir`, `Fexplorerdelete`, `Fexplorermark`, `Fexplorerstage`).
- Actions reuse existing helpers (`std.fs.write_file`, `std.fs.move`, `eve.fn.rename`, `eve.buf.focus`, `eve.state.git`) and surface results through `std.reporter`.
- Provide optional filters: `toggle_hidden`, `toggle_git_only`, `set_root` (prompted path), each flipping an observable the widget listens to.

## Lazy Loading & Pagination
- `expand(uuid)` checks `meta.loaded`. If false, call `rstd.fs.readdir`, sort entries (`directories` before files, case-insensitive), create child nodes, set `loaded = true`, and attach watchers to directories marked `expanded`.
- Hidden/ignored files are included in the readdir result; presentation filters are applied downstream so the cache remains faithful to disk.
- When a directory exceeds a threshold (default 500 entries), split rendering into pages managed by `IExplorerPaginationState` and a `std.collection.Scheduler` task that gradually appends children to avoid blocking the event loop.
- Collapse operations retain the child cache but mark `loaded = false` if `opts.discard_cache` is requested (useful for huge directories or to reclaim memory).

## Performance & Resilience Considerations
- Debounce watcher-triggered refreshes and git updates separately to avoid redundant `readdir` calls during mass changes (e.g., branch checkout).
- Guard against stale nodes by verifying `vim.loop.fs_stat` before creating buffers; if the node disappeared, remove it from the tree and cancel associated watchers.
- Detect symlink cycles using an `IExplorerVisited` set; skip recursive entry insertion when a path resolves to an ancestor.
- Provide fallback behaviour when `rstd.fs.readdir` fails (permission issues): render a placeholder child explaining the error and allow a manual retry.
- Ensure teardown closes uv handles to prevent leaks when Neovim exits or the root path switches.

## Implementation Plan
1. **State scaffolding**: build `eve.state.explorer` with root management, readdir wrapper, node metadata, and observables (no watchers yet). Provide minimal unit tests around node insertion and git status lookup.
2. **Widget skeleton**: add `lua/eve/ux/widget/explorer/explorer.lua` plus `layout.lua`/`input.lua` scaffolding. Reserve the left split, create stacked windows, render basic headers in the input pane, and show a static tree snapshot in the result pane.
3. **Command wiring**: create `fml/action/explorer` modules and register commands/keymaps; ensure open/toggle/refresh flows work manually.
4. **Lazy loading**: implement `expand`/`collapse` semantics, attach watchers only after `loaded = true`, and support manual refresh that bypasses caches.
5. **Watchers & git**: wire libuv directory watchers, debounce mutations, and hook into `eve.state.git` to display status badges.
6. **UX polish**: wire the prompt buffer to filtering/toggle observables, add winbar breadcrumbs, mark/multi-select support, batch actions, and pagination for large directories. Iterate on highlights and theme tokens.
7. **Persistence & cleanup**: persist expansion state, ensure watchers shut down cleanly, document public APIs, and add regression tests (Lua + Rust readdir cases) for edge situations (git repo churn, hidden files, mass changes).
