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

2. The Notepad window should render a **scratch** buffer.
   - The scratch buffer should have the following options:
     ```lua
     vim.bo[bufnr].buflisted = false
     vim.bo[bufnr].buftype = "nofile"
     vim.bo[bufnr].filetype = "text"
     vim.bo[bufnr].swapfile = false
     ```
   - Then I want to bind the `<c-s>` to choose a filename (popup like what we did on the save_all method did) save it without lint.
   - Then I want to bind the `<M-s>/<D-s>/<c-a>s` to choose a filename (popup like what we did on the save_all method did) save it with lint.
   - Add a normal-mode `q` mapping to close the notepad window quickly.

3. Let's create a command `Fnotepadtoggle` inside the `@lua/eve/builtin/command.lua` definitions.notepad.toggle.
   - Add a fml/action/notepad.lua to export the toggle function.
   - Bind the command to the toggle function in fml/command.lua
   - Bind the `<leader>;` key to call the toggle function.
   - Lazily construct notepad instances in the action layer so we can reuse or extend the widget later.
