----- Focus window -----
vim.keymap.set("n", "<leader>h", "<C-w>h", { noremap = true, silent = true, desc = "window: Focus on the left window" })
vim.keymap.set("n", "<leader>j", "<C-w>j", { noremap = true, silent = true, desc = "window: Focus on the bottom window" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { noremap = true, silent = true, desc = "window: Focus on the top window" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { noremap = true, silent = true, desc = "window: Focus on the right window" })

----- Split window -----
vim.keymap.set("n", "<leader>wl", "<C-w>v", { noremap = true, silent = true, desc = "window: Split window horizontally" })
vim.keymap.set("n", "<leader>wj", "<C-w>s", { noremap = true, silent = true, desc = "window: Split window vertically" })

----- Kill window -----
vim.keymap.set("n", "<leader>wd", "<cmd>close<CR>", { noremap = true, silent = true, desc = "window: close current window" })
vim.keymap.set("n", "<leader>wo", "<cmd>only<CR>", { noremap = true, silent = true, desc = "window: close others" })

----- Resize window -----
vim.keymap.set("n", "<leader>wH", "<cmd>vertical resize -1<CR>", { noremap = true, silent = true, desc = "window: Resize -1 vertically." })
vim.keymap.set("n", "<leader>wJ", "<cmd>resize -1<CR>", { noremap = true, silent = true, desc = "window: Resize -1 horizontally." })
vim.keymap.set("n", "<leader>wK", "<cmd>resize +1<CR>", { noremap = true, silent = true, desc = "window: Resize +1 horizontally." })
vim.keymap.set("n", "<leader>wL", "<cmd>vertical resize +1<CR>", { noremap = true, silent = true, desc = "window: Resize +1 vertically." })

----- Move window -----
-- vim.keymap.set("n", "<leader>wh", "<C-w>H", { noremap = true, silent = true, desc = "Window: Move the window to left-most" })
-- vim.keymap.set("n", "<leader>wj", "<C-w>J", { noremap = true, silent = true, desc = "Window: Move the window to bottom-most" })
-- vim.keymap.set("n", "<leader>wk", "<C-w>K", { noremap = true, silent = true, desc = "Window: Move the window to top-most" })
-- vim.keymap.set("n", "<leader>wl", "<C-w>L", { noremap = true, silent = true, desc = "Window: Move the window to bottom-most" })