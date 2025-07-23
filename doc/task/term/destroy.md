Support to destroy terminal.

1. Implement a command to destroy the terminal.
    - Place the command implementation into the @lua/fml/action/term/destroy.lua
    - Define the `Ftermdestroy` command in the @lua/eve/builtin/command.lua
    - Register the command in the @lua/fml/command.lua
    - Bind the `<C-w>` to call the destroy command the terminal in the @lua/eve/builtin/term.lua

2. When the command is triggered, it should launch a confirmation inputbox to ask user to confirm the "Delete the terminal (<term name>)".
3. Once user confirmed the operation, then we destroyed, and then refresh the o_termuuid.
