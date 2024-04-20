----- Focus buffer -----
vim.keymap.set("n", "<leader>1", "<cmd>BufferLineGoToBuffer 1<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 1" })
vim.keymap.set("n", "<leader>2", "<cmd>BufferLineGoToBuffer 2<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 2" })
vim.keymap.set("n", "<leader>3", "<cmd>BufferLineGoToBuffer 3<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 3" })
vim.keymap.set("n", "<leader>4", "<cmd>BufferLineGoToBuffer 4<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 4" })
vim.keymap.set("n", "<leader>5", "<cmd>BufferLineGoToBuffer 5<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 5" })
vim.keymap.set("n", "<leader>6", "<cmd>BufferLineGoToBuffer 6<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 6" })
vim.keymap.set("n", "<leader>7", "<cmd>BufferLineGoToBuffer 7<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 7" })
vim.keymap.set("n", "<leader>8", "<cmd>BufferLineGoToBuffer 8<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 8" })
vim.keymap.set("n", "<leader>9", "<cmd>BufferLineGoToBuffer 9<CR>", { noremap = true, silent = true, desc = "buffer: Goto buffer 9" })

----- Close buffer -----
vim.keymap.set("n", "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", { noremap = true, silent = true, desc = "buffer: Delete buffers to the left" })
vim.keymap.set("n", "<leader>bh", "<Cmd>BufferLineCloseRight<CR>", { noremap = true, silent = true, desc = "buffer: Delete buffers to the right" })
vim.keymap.set("n", "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", { noremap = true, silent = true, desc = "buffer: Delete other buffers" })
