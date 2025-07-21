## Terminal Conventions

1. **TerminalWindow**: the widget to places all maintained terminal buffers, support to switching, closing, renaming, and creating new terminal buffers.
2. **termline**: the winbar of the TerminalWindow,.


### TerminalWindow

* [x] The TerminalWindow should be a single instance across the whole lifecycle of the neovim instance, but its managed neovim window could be recreated/destroyed many times.
* [x] The TerminalWindow should be a floating window and exist a winbar to display the terminal buffer list.
* [x] We only show those terminal buffers that are maintained in the lua/eve/builtin/term.lua.

### Termline

1. [x] The termline should be a single instance across the whole lifecycle of the TerminalWindow.

2. [x] From the left to right of the termline:
    - [x] A list of buttons for terminals we maintained in the lua/eve/builtin/term.lua 
      - [x] Each button contains the truncated terminal name and its index.
      - [x] When click the button, it should switch to the corresponding terminal buffer.

    - [x] An **Add** button to create new terminal.
      - [x] When click the button, it should launch a select list profiles for create terminal.
        - [x] fish
        - [x] yazi 
        - [x] lazygit

