I want to support a search|replace in the buffer of current window like the vscode editor.

This feature should contains two mode, the **replace** mode and the **search** mode.

1. **search** mode: 
    - There should show a inputbox on the right-top of the editor for typing the searching query.
    - The inputbox should have a winbar that serve a series of buttons, for details:
      - `regex`: to toggle the regex pattern or plaintext pattern
      - `case_sensitive`: to toggle whether the search is case sensitive or not
      - `replace`: to switch to the **replace** mode
    - Render the matched query in the current buffer with highlight.
      - If the search window opened, when user switching window or the buffer, we need automatically re-calculate the search result and highlight the matched query in the current buffer.
2. **replace** mode:
    - There should show two inputbox on the right-top of the editor, the top inputbox is for typing the searching query, and the bottom inputbox is for typing the replacement pattern.
    - The top inputbox should have a winbar that serve a series of buttons, for details:
      - `regex`: to toggle the regex pattern or plaintext pattern
      - `case_sensitive`: to toggle whether the search is case sensitive or not
      - `replace`: to switch to the **search** mode
    - Render the matched query in the current buffer with the deleted highlight, and the replace content inline with virtual text with the added highlight.
      - If the replace window opened, when user switching window or the buffer, we need automatically re-calculate the search result and the replacement preview in the current buffer.

## Hints

1. Create a command `Fsearchbuffer` into the @lua/eve/builtin/command.lua
2. Implement the command into the  @lua/fml/action/search/buffer.lua
    - For the winbar, refer to the @lua/eve/ux/searcher/result.lua
3. Register the implementation with the command into the @lua/eve/fml/command.lua
4. Bind `C-f` to trigger the `Fsearchbuffer` command in the @lua/eve/builtin/keymap.lua

