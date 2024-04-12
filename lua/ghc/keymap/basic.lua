-- Insert mode -------------------------------------------------------------------------------------

------------------------------------------------------------------------------------- Insert mode --

-- Normal mode -------------------------------------------------------------------------------------

vim.keymap.set("n", "<Esc>", "<cmd>nohl<CR>", { noremap = true, silent = true, desc = "Remove search highlights" })

----- Focus window -----
vim.keymap.set("n", "<leader>h", "<C-w>h", { noremap = true, silent = true, desc = "Window: Focus on the left window" })
vim.keymap.set("n", "<leader>j", "<C-w>j", { noremap = true, silent = true, desc = "Window: Focus on the bottom window" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { noremap = true, silent = true, desc = "Window: Focus on the top window" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { noremap = true, silent = true, desc = "Window: Focus on the right window" })

----- Split window -----
vim.keymap.set("n", "<leader><C-l>", "<C-w>v", { noremap = true, silent = true, desc = "g: Split window horizontally" })
vim.keymap.set("n", "<leader><C-j>", "<C-w>s", { noremap = true, silent = true, desc = "Window: Split window vertically" })

----- Move window -----
vim.keymap.set("n", "<leader>wh", "<C-w>H", { noremap = true, silent = true, desc = "Window: Move the window to left-most" })
vim.keymap.set("n", "<leader>wj", "<C-w>J", { noremap = true, silent = true, desc = "Window: Move the window to bottom-most" })
vim.keymap.set("n", "<leader>wk", "<C-w>K", { noremap = true, silent = true, desc = "Window: Move the window to top-most" })
vim.keymap.set("n", "<leader>wl", "<C-w>L", { noremap = true, silent = true, desc = "Window: Move the window to bottom-most" })

----- Resize window -----
vim.keymap.set("n", "<leader><C-Left>", "<cmd>vertical resize -3<CR>", { noremap = true, silent = true, desc = "Window: Resize -3 vertically." })
vim.keymap.set("n", "<leader><C-Down>", "<cmd>resize -3<CR>", { noremap = true, silent = true, desc = "Window: Resize -3 horizontally." })
vim.keymap.set("n", "<leader><C-Up>", "<cmd>resize +3<CR>", { noremap = true, silent = true, desc = "Window: Resize +3 horizontally." })
vim.keymap.set("n", "<leader><C-Right>", "<cmd>vertical resize +3<CR>", { noremap = true, silent = true, desc = "Window: Resize +3 vertically." })

------------------------------------------------------------------------------------- Normal mode --

-- Visual mode -------------------------------------------------------------------------------------

vim.keymap.set("v", "J", "<cmd>m '>+1<CR>gv=gv", { noremap = true, silent = true, desc = "" })
vim.keymap.set("v", "K", "<cmd>m '<-2<CR>gv=gv", { noremap = true, silent = true, desc = "" })

------------------------------------------------------------------------------------- Visual mode --

-- Terminal mode -----------------------------------------------------------------------------------

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { noremap = true, silent = true, desc = "Exit terminal mode" })

----------------------------------------------------------------------------------- Terminal mode --
