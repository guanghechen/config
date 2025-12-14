## Overview

The notepad feature provides a floating, markdown-friendly scratch area for lightweight notes tied to the current workspace. It is composed of:
- A persistent data store exposed via `_G.eve.notepad`
- A floating widget (`eve.ux.widget.Notepad`) that renders the active note and handles input
- An action layer (`fml.action.notepad`) that wires commands and UI prompts
- A nvimbar component that lists notes and exposes quick navigation

The current implementation assumes a single persistence backend (the active workspace). Upcoming work will add a `source` dimension so the notepad framework can pull notes from alternative locations (e.g., editor-wide or shared stores).

## Data Model (`lua/eve/builtin/notepad.lua`)

- Persists to `yoz.path.locate_workspace_filepath("notepad.json")`. The snapshot tracks items, their display order, and the active UUID.
- `INotepadItem` schema includes `uuid`, human-readable `name`, free-form `content`, and ISO8601 `created_at`/`updated_at` timestamps.
- Maintains in-memory `items_map`, `orders`, the active UUID, and an observable (`o_active_uuid`) so other modules can react to selection changes.
- Guarantees at least one item exists (allocates an untitled note on startup) and normalises blank names to `dot.var.BUF_UNTITLED`.
- Auto-saves with a 10 s `ark.timer.debounce` and exposes `save/flush` helpers for manual persistence.
- `set_content` updates timestamps and mirrors the special `chatbox` note into any buffer tagged with `eve.notepad.BUFFER_VAR`, keeping AI/chat integrations in sync.
- Exposes a full CRUD surface (`create`, `ensure_named_item`, `remove`, `rename`, `set_content`, `append_content`) plus navigation helpers (`focus_*`, `swap_*`, `iterator`, `current`).

## Action Layer (`lua/fml/action/notepad.lua`)

- Lazily instantiates `eve.ux.widget.Notepad` widgets keyed by identifier; the default instance drives the toggle/show commands.
- Ensures the store is initialised and focused before presenting the UI, creating a new untitled note when nothing exists.
- Routes user commands (`Fnotepadtoggle`, `Fnotepadsave`, `Fnotepadcreate`, `Fnotepadrename`, `Fnotepaddestroy`, focus/swap variants, etc.) into store mutations and widget updates.
- Flushes all live widget buffers before saving so edits from multiple windows land in the JSON snapshot coherently.
- Provides interactive prompts for create/rename/destroy flows and reports results through `ark.reporter`.
- Offers `append_content` as a convenience hook that appends to—or auto-creates—the `chatbox` note, then focuses the widget for immediate review.

## Widget (`lua/eve/ux/widget/notepad.lua`)

- Renders a centred floating window sized via `eve.box.measure`; respects configurable min/max dimensions and theme winblend.
- Backs the view with an unlisted, hidden, nofile buffer (`bufhidden = "hide"`, `filetype = "markdown"`, `modifiable = true`, `swapfile = false`). Markdown rendering plugins are explicitly disabled for the buffer.
- Registers a broad keymap surface:
  - `<C-s>`, `<C-a>s`, `<D-s>`, `<M-s>` → save/flush
  - `<C-n>` rename (consistent in insert/normal/visual modes)
  - `<C-/>` create note
  - `<C-d>` / `<leader>dd` destroy
  - `<C-,>` / `<C-.>` focus previous/next
  - `<C-S-,>` / `<C-S-.>` swap left/right
  - `<C-1>`…`<C-9>` jump to indexed notes
  - `<leader><cr>` forwards to AI submit commands (buffer/selection variants)
  - `q` closes the window
- Mirrors every text change back into the store via buffer autocmds (`TextChanged`, `TextChangedI`, `TextChangedP`) while suppressing re-entrant sync.
- Subscribes to `eve.notepad.o_active_uuid` so switching notes rerenders the buffer and refreshes winbar content.
- Integrates with `eve.ux.nvimbar.Nvimbar`, exposing the note list and add button inside the floating window’s winbar.

## Nvimbar Component (`lua/eve/ux/nvimbar/component/notepad.lua`)

- Builds truncated labels (`<=12` characters) paired with index badges and stylised separators.
- Keeps the active note centred where space allows; otherwise shows navigation arrows with accurate counts of hidden entries.
- Delegates interactivity to anonymous `eve.G` functions so bar clicks can focus notes, add new ones, or navigate left/right.
- Shares theming tokens with the rest of the nvimbar ecosystem to keep the widget visually aligned.

## Commands, Keymaps, and Persistence

- Commands are defined under `dot.command.definitions.notepad.*` and wired via `fml/command.lua`. Most commands operate without arguments; focus/swap variants accept an optional numeric count.
- Widget keymaps are buffer-local, installed each time a notepad buffer is created, and respect aliases for cross-platform modifier keys.
- `Notepad.flush_to_disk()` creates parent directories when needed and emits a `ark.reporter.info` notification on success.
- `eve.notepad.flush()` is safe to call during Neovim shutdown (e.g., autocmd hooks) to guarantee the debounce queue is emptied.

## Upcoming: `source` Abstraction

To support multiple persistence backends (workspace, global/editor-level, shared notebooks), we will introduce a `source` dimension:
- Extend `INotepadItem` (and persisted JSON) with a `source` field that identifies the storage origin. Default to `"workspace"` to preserve current behaviour.
- Update `eve.notepad` to segment items, order, and activation per source while maintaining shared helpers (e.g., navigation within the active source).
- Allow widget instances to declare their target source via props; the action layer can then spin up specialised widgets (e.g., `global` notes vs. project notes).
- Teach save/load routines to resolve filepaths based on source (workspace file vs. global config dir) while keeping autosave semantics intact.
- Review integrations such as the `chatbox` sync to ensure they select the right source or opt into cross-source operations explicitly.

Documenting these requirements now ensures the upcoming refactor has clear guardrails and highlights the touchpoints that must become source-aware.
