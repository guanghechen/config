Implement a Terminal widget experience that mirrors the ergonomics of the Notepad widget while remaining tailored to running shell jobs.

## Terminal Behavior

1. The Terminal widget lives at `lua/dot/module/term/widget.lua` and exposes the shared widget interface so other modules can focus / toggle it.
   - A floating window is centred in the editor with a rounded border (`relative = "editor"`) and the following window styling:
     ```lua
     vim.wo[winnr].cursorline = false
     vim.wo[winnr].list = false
     vim.wo[winnr].number = false
     vim.wo[winnr].relativenumber = false
     vim.wo[winnr].signcolumn = "no"
     vim.wo[winnr].spell = false
     vim.wo[winnr].winfixbuf = true
     vim.wo[winnr].wrap = true
     vim.wo[winnr].winblend = 0
     vim.wo[winnr].winhighlight = "Cursor:f_us_terminal_current,..."
     ```
   - The window initially opens with an internal mask buffer (`filetype = ark.filetype.TERM_MASK`) to keep the layout stable while the real terminal buffer is attached.
   - `termline` (the terminal winbar) renders inside this floating window; any time the window resizes the widget recomputes its max width and re-renders the bar.

2. Each terminal tab runs in a dedicated buffer created by `dot.term.state.create`:
   - Buffer options match expectations for pseudo terminals:
     ```lua
     vim.bo[bufnr].buflisted = false
     vim.bo[bufnr].filetype = ark.filetype.TERM
     vim.bo[bufnr].modifiable = false
     vim.bo[bufnr].readonly = false
     vim.bo[bufnr].swapfile = false
     ```
   - When the widget focuses a terminal (`:focus()` / `:toggle_and_focus()`), it ensures the buffer exists, opens the float, and starts the job with `vim.fn.jobstart(..., { pty = true })`.
   - `toggle_and_focus` accepts creation metadata and optional `selected_text`; if a job already exists the text is piped to `termmeta.jobid` after focus.
   - `TermClose` autocmds translate vim events back through `dot.term.event.on_closed` so the store stays consistent even when the user exits the program inside the terminal.

3. The terminal winbar mirrors the Notepad UX and keeps long lists approachable:
   - `lua/dot/module/nvimbar/component/term.lua` exposes `items(position)` and `add_button(position)`. Legacy consumers can still call `term.terms`.
   - Items show truncated terminal names (12-character budget), the 1-based index badge, and consistent separators. Active entries reuse the focused highlight palette.
   - The winbar keeps the active terminal centred when space allows; overflow places clickable left/right arrow buttons with hidden counts that call the focus-left/right actions.
   - The add button always renders when width permits and invokes `Ftermcreate`.
   - Width calculations call `vim.api.nvim_win_get_width(_terminal_winnr)` so re-renders match the float dimensions rather than the full screen.

4. Default keymaps and commands stay aligned with the action layer:
   - `Ftermtoggle`, `Ftermcreate`, `Ftermrename`, `Ftermdestroy`, `Ftermfocus{1-9}`, `Ftermfocusleft`, `Ftermfocusright`, `Ftermswapleft`, `Ftermswapright`, and more live under `dot.command.definitions.term`.
   - `lua/fml/action/term/*.lua` bridges these commands to widget functions, manages prompts (rename, destroy confirmation), and triggers `dot.state.status.dirtier_termline:mark_dirty()` so the winbar reflects the new state.
   - Each terminal profile includes its launch command and type; profiles can be selected via the UI picker defined in `fml/action/term/create.lua`.

----------------------------------------------------------------------------------------------------

## Module Overview

### Data Model (`lua/dot/module/term/state.lua`)
- Stores active terminals keyed by UUID (`metamap`) and maintains their order (`termlist`).
- Exposes CRUD helpers (`create`, `update`, `append`, `focus`, `swap`, `iterator`, `pick_next_term`) that the widget and action layers depend on.
- Persists per-terminal metadata (name, cmd, cwd, env, jobid) while deferring actual process lifecycle to the widget.
- Publishes the `o_termuuid` observable so subscribers (widget winbar, status dirtier) react to focus changes.

### Action Layer (`lua/fml/action/term/*.lua`)
- `create.lua` handles profile selection, shell defaults, toggle behaviour, and rename prompts.
- `destroy.lua` confirms deletions, picks a fallback terminal, and raises the dirtier when state changes.
- `focus.lua`, `swap.lua`, `yazi.lua`, `lazygit.lua`, and related modules glue user commands to `dot.term` navigation helpers.
- Every action routes notifications through `ark.reporter` and ensures `dot.state.status.dirtier_termline` is marked so the widget winbar stays current.

### Widget (`lua/dot/module/term/widget.lua`)
- Owns the floating window lifecycle, mask buffer, terminal buffer creation, and `jobstart` integration.
- Implements the shared widget API (`focus`, `toggle`, `toggle_and_focus`, `hide`, `resize`, `isvisible`, `isfocused`).
- Observes `dot.term.state.o_termuuid` to keep the visible buffer in sync and uses `dot.state.status.dirtier_termline` to throttle winbar renders.
- When autofocus is requested and text is provided, schedules `vim.api.nvim_chan_send` to feed the active terminal job.

### Nvimbar Component (`lua/dot/module/nvimbar/component/term.lua`)
- Renders terminals with truncated names, index badges, separators, and a persistent "+" button.
- Uses the same centred-scroll strategy as the Notepad bar; arrow buttons display hidden counts and call the existing focus commands.
- Highlights reuse the theming defined in `dot.hlgroup.nvimbar`, so focused terminals share the look-and-feel of other widgets.
- Exposes `M.terms` for legacy code paths while new integrations should prefer `M.items` and `M.add_button`.
