
## Maximize Feature Redesign

I'd like to redesign the maximize feature to improve user experience:

1. Keep at most one maximized window:
   ```lua
   -- lua/eve/state/maximized.lua

   ---@class eve.state.maximized.IOriginalWindow
   ---@field public winnr             integer
   ---@field public winblend          integer
   ---@field public wincfg            vim.api.keyset.win_config

   ---@class eve.state.maximized.IContext
   ---@field public original          eve.state.maximized.IOriginalWindow|nil
   ```
   - Track the active maximized float inside `eve.state.maximized` (see `lua/eve/state/maximized.lua`).
   - Persist the window handle, its original `winblend`, and a deepcopy of the `vim.api.nvim_win_get_config` payload so we can restore everything (including position / zindex / border) later.

2. Toggle behaviour for floating windows:
   - If `eve.state.maximized.get_original()` points to the same window, call `restore_original` to reinstate the saved config, reapply the stored `winblend`, and clear the state.
   - If another window is currently maximized, restore that window first before proceeding.
   - Snapshot the target float’s config and `winblend`, then reconfigure it in place:
     - Switch to `relative = "editor"` anchored at `"NW"` with `row = top_offset` and `col = 0`, where `top_offset` is 1 when the tabline is visible, otherwise 0. Compute `available_height = editor_height - top_offset - bottom_offset`, subtracting `bottom_offset = 1` when the statusline is visible.
     - Use `eve.box.fit_editor` to clamp width and height to the remaining editor area (accounting for tabline, statusline, and border thickness). Always promote the window’s z-index to a high constant so the float sits in front of everything else.
     - Force `winblend = 0` so the maximized float becomes fully opaque while maximized.

3. Restoration:
   - On exit (manual toggle or failure to apply the maximized config) reuse the saved config via `vim.api.nvim_win_set_config`, reset the original `winblend`, and clear `eve.state.maximized`.

4. Non-floating windows remain untouched; ignore maximize requests for fixed windows for now.
