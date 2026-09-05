# Window Focus Ownership Audit

Status: draft, review pending

## Scope

This audit covers repository-owned window creation and delayed focus, cursor, view, and mode mutations.
The current implementation has 32 direct floating-window creation sites: 16 enter the window immediately
and 16 create it in the background.

Passive floats such as ext-cmdline, popupmenu, notifier toasts, and win separators do not
normally enter themselves. The material risks are concentrated in modal lifecycle code and scheduled commands
that lose their target window.

## Findings

### F-001: modal input/select restore stale focus and cursor

- Locations: `lua/era/m/input.lua`, `lua/era/m/select/init.lua`, `lua/era/m/select/view.lua`, and prompt callers under
  `lua/era/fn/find-explorer.lua`, `lua/era/m/picker/composer/filetree.lua`, and
  `lua/era/m/searcher/composer/filetree.lua`.
- Trigger: an input/select float is open and the user or another callback enters a different window before
  scheduled mount, cancel, or dispose callbacks settle.
- Evidence: headless reproductions show the final current window returning to the captured parent instead of
  the window selected by the user. Input also restores a captured cursor into a replacement buffer when the
  parent window changes buffers while the modal is open.
- Impact: visible focus bounce, cursor jumps, and stale cursor coordinates applied to the wrong buffer.
- Root cause: mount, modal dispose, and callers independently write current-window state. Validity checks do
  not establish focus ownership or buffer identity.

### F-002: normal-window maximize steals focus when dismissed by WinEnter

- Location: `lua/era/m/maximize.lua`.
- Trigger: a normal window is represented by a maximized float and another normal window is entered.
- Evidence: the `WinEnter` callback schedules `close_normal()`, which unconditionally focuses the original
  parent window. A headless reproduction selects a second normal window but ends on the original parent.
- Impact: the newly selected window is immediately replaced by the old focus.

### F-003: deferred diffview fold commands execute in the current window

- Locations: active implementation `lua/era/m/diffview/pane/sbs.lua`; duplicate implementation
  `lua/era/m/diffview/window.lua`.
- Trigger: diffview schedules `zM` or `zR` for an SBS window and current focus changes before the callback runs.
- Evidence: the callback validates the intended `winnr` but runs `vim.cmd("normal! ...")` without
  `nvim_win_call`. A headless reproduction closes folds in an unrelated current window.
- Impact: unrelated fold, view, and cursor state changes.

### F-004: scheduled mode/cursor commands lose their semantic target

- Representative locations: `lua/dot/win.lua`, `lua/era/m/term/widget.lua`,
  `lua/era/m/lsp/event.lua`, `lua/era/view/textarea.lua`, `lua/era/m/lsp/diagnostic.lua`, and
  `lua/era/m/ai/term.lua`.
- Trigger: focus or buffer identity changes before scheduled `startinsert`, `stopinsert`, cursor, or focus
  mutations execute.
- Evidence: callbacks commonly check only that a captured window handle remains valid; global mode commands
  act on whichever window is current at execution time.
- Impact: intermittent mode changes, cursor movement in a replacement buffer, or delayed focus theft.

### F-005: popupmenu focusability contract is inconsistent

- Locations: `lua/dot/win.lua` and `lua/era/dressing/ui_attach/popupmenu.lua`.
- Trigger: window picking runs while the ext-popupmenu is visible.
- Evidence: popupmenu is configured with `focusable = false`, while `dot.win.is_focusable()` classifies its
  semantic window type as focusable.
- Impact: explicit window picking may select a window that its native configuration declares non-focusable.

## Repair Order

1. F-001: establish one modal focus owner for input/select.
2. F-002: preserve the newly entered window when maximize closes because of `WinEnter`.
3. F-003: bind deferred diffview commands with `nvim_win_call`.
4. F-004: bind scheduled mode/cursor operations to `(winnr, bufnr, generation)`.
5. F-005: align semantic and native focusability.

## Phase 1 Contract

The first repair covers F-001 only.

- Closing or disposing a modal must not unconditionally focus its captured parent.
- Modal callbacks must not restore a cursor captured from a different buffer identity.
- Leaving a modal for another window revokes the modal's right to restore focus.
- Deferred focus needed after `nvim_win_call` remains valid only until the modal observes `BufLeave` or its
  temporary pre-mount `WinEnter` watch observes a non-modal target; user navigation revokes it synchronously
  before scheduled focus can run.
- Callers receive the choice/input result but do not independently restore current-window state.

## Unresolved Questions

- Whether nested modals should form an explicit stack after the first repair is verified.
- Whether smooth-scroll animations should be cancelled on `WinLeave`.
- Whether the duplicate diffview window helper should be removed when F-003 is addressed.
