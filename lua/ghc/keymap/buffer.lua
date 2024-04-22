----- Focus buffer -----
vim.keymap.set("n", "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 1" })
vim.keymap.set("n", "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 2" })
vim.keymap.set("n", "<leader>3", "<cmd>BufferLineGoToBuffer 3<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 3" })
vim.keymap.set("n", "<leader>4", "<cmd>BufferLineGoToBuffer 4<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 4" })
vim.keymap.set("n", "<leader>5", "<cmd>BufferLineGoToBuffer 5<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 5" })
vim.keymap.set("n", "<leader>6", "<cmd>BufferLineGoToBuffer 6<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 6" })
vim.keymap.set("n", "<leader>7", "<cmd>BufferLineGoToBuffer 7<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 7" })
vim.keymap.set("n", "<leader>8", "<cmd>BufferLineGoToBuffer 8<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 8" })
vim.keymap.set("n", "<leader>9", "<cmd>BufferLineGoToBuffer 9<cr>", { noremap = true, silent = true, desc = "buffer: Goto buffer 9" })

----- Close buffer -----
vim.keymap.set("n", "<leader>bl", "<Cmd>BufferLineCloseLeft<cr>", { noremap = true, silent = true, desc = "buffer: Delete buffers to the left" })
vim.keymap.set("n", "<leader>bh", "<Cmd>BufferLineCloseRight<cr>", { noremap = true, silent = true, desc = "buffer: Delete buffers to the right" })
vim.keymap.set("n", "<leader>bo", "<Cmd>BufferLineCloseOthers<cr>", { noremap = true, silent = true, desc = "buffer: Delete other buffers" })
