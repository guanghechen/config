Support to rename terminal. ✅ COMPLETED

1. Implement a command to rename the terminal. ✅ COMPLETED
    - Place the command implementation into the @lua/fml/action/term/create.lua ✅ 
    - Define the `Ftermrename` command in the @lua/eve/builtin/command.lua ✅
    - Register the command in the @lua/fml/command.lua ✅
    - Bind the `<C-r>` to call the rename command the terminal in the `lua/eve/builtin/term.lua` ✅

2. When the command is triggered, it should launch a inputbox to typing the new name and should check if it's not blanking. ✅ COMPLETED
3. Once user confirmed the new name and it's different to the old name, then thats update it in the @lua/eve/builtin/term.lua ✅ COMPLETED
