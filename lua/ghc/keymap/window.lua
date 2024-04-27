local action = require("ghc.action.window")

----- Focus window -----
vim.keymap.set("n", "<leader>wh", action.focus_window_left, { noremap = true, silent = true, desc = "window: Focus on the left window" })
vim.keymap.set("n", "<leader>wj", action.focus_window_bottom, { noremap = true, silent = true, desc = "window: Focus on the bottom window" })
vim.keymap.set("n", "<leader>wk", action.focus_window_top, { noremap = true, silent = true, desc = "window: Focus on the top window" })
vim.keymap.set("n", "<leader>wl", action.focus_window_right, { noremap = true, silent = true, desc = "window: Focus on the right window" })
vim.keymap.set("n", "<leader>ww", action.focus_window_with_picker, { noremap = true, silent = true, desc = "window: Focus window (with picker)" })

----- Swap window -----
vim.keymap.set("n", "<leader>ws", action.swap_window_with_picker, { noremap = true, silent = true, desc = "window: Swap window (with picker)" })

----- Project window ----
vim.keymap.set("n", "<leader>wp", action.project_window_with_picker, { noremap = true, silent = true, desc = "window: Project window (with picker)" })

----- Split window -----
vim.keymap.set("n", "<leader>w-", action.split_window_horizontal, { noremap = true, silent = true, desc = "window: Split window horizontally" })
vim.keymap.set("n", "<leader>w|", action.split_window_vertical, { noremap = true, silent = true, desc = "window: Split window vertically" })

----- Kill window -----
vim.keymap.set("n", "<leader>wd", action.close_window_current, { noremap = true, silent = true, desc = "window: close current window" })
vim.keymap.set("n", "<leader>wo", action.close_window_others, { noremap = true, silent = true, desc = "window: close others" })
