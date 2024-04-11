-- Insert mode -------------------------------------------------------------------------------------

------------------------------------------------------------------------------------- Insert mode --

-- Normal mode -------------------------------------------------------------------------------------

vim.keymap.set("n", "<Esc>", "<cmd>nohl<CR>", { noremap = true, silent = true, desc = "Remove search highlights" })

----- Split pane -----
vim.keymap.set("n", "<leader>L", "<C-w>v", { noremap = true, silent = true, desc = "Window: Split pane horizontally" })
vim.keymap.set("n", "<leader>J", "<C-w>s", { noremap = true, silent = true, desc = "Window: Split pane vertically" })

----- Focus pane -----
vim.keymap.set("n", "<leader>h", "<C-w>h", { noremap = true, silent = true, desc = "Window: Focus on the left pane" })
vim.keymap.set("n", "<leader>j", "<C-w>j", { noremap = true, silent = true, desc = "Window: Focus on the bottom pane" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { noremap = true, silent = true, desc = "Window: Focus on the top pane" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { noremap = true, silent = true, desc = "Window: Focus on the right pane" })

----- Move pane -----
vim.keymap.set("n", "<leader><Left>", "<C-w>H", { noremap = true, silent = true, desc = "Window: Move the pane to left-most" })
vim.keymap.set("n", "<leader><Down>", "<C-w>J", { noremap = true, silent = true, desc = "Window: Move the pane to bottom-most" })
vim.keymap.set("n", "<leader><Up>", "<C-w>K", { noremap = true, silent = true, desc = "Window: Move the pane to top-most" })
vim.keymap.set("n", "<leader><Right>", "<C-w>L", { noremap = true, silent = true, desc = "Window: Move the pane to bottom-most" })

----- Resize pane -----
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
