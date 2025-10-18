Implement a Notepad widget inside the ux/widget/notepad.lua.

## Notepad Behavior

1. The Notepad widget should be implemented as a class so additional notepad variants can reuse it, and it should render a floating window on the center of the screen.
   - The window should have the following options:
     ```lua
     vim.wo[winnr].cursorline = true
     vim.wo[winnr].list = true
     vim.wo[winnr].number = true
     vim.wo[winnr].relativenumber = true
     vim.wo[winnr].signcolumn = "yes"
     vim.wo[winnr].spell = true
     vim.wo[winnr].winfixbuf = true
     vim.wo[winnr].wrap = true
     ```

2. The Notepad window renders a **scratch** buffer created in `lua/eve/ux/widget/notepad.lua`.
   - Buffer options match the scratch expectations:
     ```lua
     vim.bo[bufnr].buflisted = false
     vim.bo[bufnr].buftype = "nofile"
     vim.bo[bufnr].filetype = "text"
     vim.bo[bufnr].swapfile = false
     ```
   - Content changes propagate back into the notepad store on every text-change autocmd and through the action layer (`lua/fml/action/notepad.lua`), so the JSON snapshot stays current without dedicated save prompts.
   - `<C-s>` flushes the pending edits for all active widgets to the workspace `notepad.json` file (no prompt, no linting side-effects).
   - `<C-a>s`, `<D-s>`, and `<M-s>` are aliases to the same flush behaviour so the key works across macOS / Linux / Windows layouts.
   - Normal mode `q` closes the widget window.
   - Add a normal-mode `q` mapping to close the notepad window quickly.

3. Let's create a command `Fnotepadtoggle` inside the `@lua/eve/builtin/command.lua` definitions.notepad.toggle.
   - Add a fml/action/notepad.lua to export the toggle function.
   - Bind the command to the toggle function in fml/command.lua
   - Bind the `<leader>;` key to call the toggle function.
   - Lazily construct notepad instances in the action layer so we can reuse or extend the widget later.

----------------------------------------------------------------------------------------------------

The Notepad should ship with a winbar comparable to the terminal widget so the UX feels consistent.

1. Persist notepad data per workspace at `std.path.locate_workspace_filepath("notepad.json")`, tracking the items, their order, and the active uuid (see `INotepadItem`).
2. Provide create / destroy / rename / reorder / focus / swap operations via both widget keymaps and command bindings, mirroring `lua/eve/ux/widget/terminal.lua`.
3. Render every note in the winbar with a truncated name, the 1-based index badge, terminal-style separators, and an always-present “add” button. Active items should reuse the focused styling.
4. Auto-save changes on a short debounce (~10 s) and keep `<C-s>` / `<C-a>s` (and aliases) wired to the flush command so users can force persistence at any time.
5. The nvimbar component ensures long note lists remain usable: when entries overflow, it renders left/right arrow buttons with hidden counts, matching the behaviour shipped in `lua/eve/ux/nvimbar/component/notepad.lua`.

## Module Overview

### Data Model (`lua/eve/builtin/notepad.lua`)
- Stores notepad items (UUID, name, content, timestamps) and persists them to `std.path.locate_workspace_filepath("notepad.json")`.
- Exposes CRUD helpers (`create`, `remove`, `rename`, `set_content`, `focus_*`, `swap_*`, `iterator`) that the widget and action layers consume.
- Maintains an auto-save timer (`std.timer.debounce`) so edits hit disk even without manual flushes.

### Action Layer (`lua/fml/action/notepad.lua`)
- Lazily constructs `eve.ux.widget.Notepad` instances keyed by name; defaults to the `text` scratch configuration.
- Bridges commands to widget behaviour (toggle, show, close, save, create, rename, destroy, focus, swap) and keeps all widgets in sync before flushing.
- Provides user-facing prompts (e.g., new note name, rename confirmation) and routes status messages through `std.reporter`.

### Widget (`lua/eve/ux/widget/notepad.lua`)
- Implements the floating window, scratch buffer setup, autocmd wiring, and winbar rendering.
- Registers all notepad keymaps:
  - `<C-s>` / `<C-a>s` / `<D-s>` / `<M-s>` → `Fnotepadsave`
  - `<C-n>` create, `<C-r>` rename, `<C-d>` destroy
  - `<C-,>` / `<C-.>` focus previous/next
  - `<C-S-,>` / `<C-S-.>` swap positions
  - `<C-1>`…`<C-9>` jump directly to a note
  - `q` close the window
- Syncs buffer edits to the backing store on every change and keeps the winbar view (`eve.ux.nvimbar.Nvimbar`) updated when active note or layout changes.

### Nvimbar Component (`lua/eve/ux/nvimbar/component/notepad.lua`)
- Renders the notepad entries with truncated titles, index badges, separators, and an always-visible add button.
- Mirrors the buffer bar scrolling strategy: the active note stays centred when possible, hidden entries are represented by arrow buttons with accurate counts, and the component accounts for available width dynamically.
- Shares styling with the focused/normal variants defined in `eve.constant.hlgroup.nvimbar`.
