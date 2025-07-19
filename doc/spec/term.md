# Terminal Specification

## Behaviors

* There is one and only one window to rendering the terminal, let's call it as the TerminalWindow.
  - No matter where we open or create a new terminal, it should immediately open the TerminalWindow and render the terminal buffer into it.
  - The TerminalWindow should be a floating window and exist a winbar to display the terminal buffer list.
  - Keep in mind, the nvimbar of TerminalWindow should be a single instance, that is, although the TerminalWindow could be rebuild caused by it could be closed before, but we still can reuse the nvimbar instance into the new TerminalWindow.

* When open a new terminal, we should maintain the terminal meta and state into the `lua/eve/builtin/term.lua`.

