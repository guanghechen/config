-- ----- Focus buffer -----
-- vim.keymap.set("n", "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 1" })
-- vim.keymap.set("n", "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 2" })
-- vim.keymap.set("n", "<leader>3", "<cmd>BufferLineGoToBuffer 3<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 3" })
-- vim.keymap.set("n", "<leader>4", "<cmd>BufferLineGoToBuffer 4<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 4" })
-- vim.keymap.set("n", "<leader>5", "<cmd>BufferLineGoToBuffer 5<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 5" })
-- vim.keymap.set("n", "<leader>6", "<cmd>BufferLineGoToBuffer 6<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 6" })
-- vim.keymap.set("n", "<leader>7", "<cmd>BufferLineGoToBuffer 7<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 7" })
-- vim.keymap.set("n", "<leader>8", "<cmd>BufferLineGoToBuffer 8<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 8" })
-- vim.keymap.set("n", "<leader>9", "<cmd>BufferLineGoToBuffer 9<cr>", { noremap = true, silent = true, desc = "buffer: Open buffer 9" })
--
-- ----- Close buffer -----
-- vim.keymap.set("n", "<leader>bl", "<Cmd>BufferLineCloseLeft<cr>", { noremap = true, silent = true, desc = "buffer: Delete buffers to the left" })
-- vim.keymap.set("n", "<leader>bh", "<Cmd>BufferLineCloseRight<cr>", { noremap = true, silent = true, desc = "buffer: Delete buffers to the right" })
-- vim.keymap.set("n", "<leader>bo", "<Cmd>BufferLineCloseOthers<cr>", { noremap = true, silent = true, desc = "buffer: Delete other buffers" })

-- nvchad tabufline

local action = require("ghc.core.action.buffer")

----- Focus buffer -----
vim.keymap.set("n", "<leader>b1", action.open_buffer_1, { noremap = true, silent = true, desc = "buffer: Open buffer 1" })
vim.keymap.set("n", "<leader>b2", action.open_buffer_2, { noremap = true, silent = true, desc = "buffer: Open buffer 2" })
vim.keymap.set("n", "<leader>b3", action.open_buffer_3, { noremap = true, silent = true, desc = "buffer: Open buffer 3" })
vim.keymap.set("n", "<leader>b4", action.open_buffer_4, { noremap = true, silent = true, desc = "buffer: Open buffer 4" })
vim.keymap.set("n", "<leader>b5", action.open_buffer_5, { noremap = true, silent = true, desc = "buffer: Open buffer 5" })
vim.keymap.set("n", "<leader>b6", action.open_buffer_6, { noremap = true, silent = true, desc = "buffer: Open buffer 6" })
vim.keymap.set("n", "<leader>b7", action.open_buffer_7, { noremap = true, silent = true, desc = "buffer: Open buffer 7" })
vim.keymap.set("n", "<leader>b8", action.open_buffer_8, { noremap = true, silent = true, desc = "buffer: Open buffer 8" })
vim.keymap.set("n", "<leader>b9", action.open_buffer_9, { noremap = true, silent = true, desc = "buffer: Open buffer 9" })
vim.keymap.set("n", "<leader>b0", action.open_buffer_10, { noremap = true, silent = true, desc = "buffer: Open buffer 10" })
vim.keymap.set("n", "<leader>b[", action.open_buffer_left, { noremap = true, silent = true, desc = "buffer: Open buffer left" })
vim.keymap.set("n", "<leader>b]", action.open_buffer_right, { noremap = true, silent = true, desc = "buffer: Open buffer right" })
vim.keymap.set("n", "[b", action.open_buffer_left, { noremap = true, silent = true, desc = "buffer: Open buffer left" })
vim.keymap.set("n", "]b", action.open_buffer_right, { noremap = true, silent = true, desc = "buffer: Open buffer right" })

----- Close buffer -----
vim.keymap.set("n", "<leader>bd", action.close_buffer, { noremap = true, silent = true, desc = "buffer: Close current buffer" })
vim.keymap.set("n", "<leader>bl", action.close_buffer_lefts, { noremap = true, silent = true, desc = "buffer: Close buffers to the left" })
vim.keymap.set("n", "<leader>bh", action.close_buffer_rights, { noremap = true, silent = true, desc = "buffer: Close buffers to the right" })
vim.keymap.set("n", "<leader>bo", action.close_buffer_others, { noremap = true, silent = true, desc = "buffer: Close other buffers" })
vim.keymap.set("n", "<leader>ba", action.close_buffer_others, { noremap = true, silent = true, desc = "buffer: Close all buffers" })
