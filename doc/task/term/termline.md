I want to add winbar for term buffers. This is the detailed specification to guide you how to complete the task, read below contents carefully and then start to implement it. Once you finished some part or step, please mark it as done in this specification.

## Requirements

1. Feat: implement a nvimbar component named `term` like what the `lua/eve/ux/nvimbar/component/buf.lua` did.

    - [x] List all the terminal buffers, and render each with the format of `<index> <term_name> `. BE AWARE: we use absolute index instead of relative index which is different in the `lua/eve/ux/nvimbar/component/buf.lua`.
    - [x] Each term item could be clickable, and when clicked, it should switch to the corresponding terminal buffer.
    - [x] The code style should be similar to the existing `buf` component in `lua/eve/ux/nvimbar/component/buf.lua`.

2. Feat: integrate the `term` component into the existing winbar setup.

    - [x] You should handle the winbar in `lua/fml/dressing/nvimbar/winline.lua` for term buffers.

3. Feat: mechanism to trigger the term winbar rendering.

    - [x] add a dirtier_termline similar like the dirtier_statusline in `lua/eve/builtin/status.lua`

4. Bind `C-<1-9>` to switch to the corresponding term buffer by index like what the buffer did.

    - [x] Implemented C-<1-9> keybindings for terminal focus (only bind for the terminal buffers).

## Hints

1. MUST: the termline should unique like what the statusline and the tabline did.

