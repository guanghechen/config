local actions = {
  buffer = require("ghc.core.action.buffer"),
  window = require("ghc.core.action.window"),
}

-- fast navigation

-- window
vim.keymap.set("n", "<leader>h", actions.window.focus_window_left, { noremap = true, silent = true, desc = "window: Focus on the left window" })
vim.keymap.set("n", "<leader>j", actions.window.focus_window_bottom, { noremap = true, silent = true, desc = "window: Focus on the bottom window" })
vim.keymap.set("n", "<leader>k", actions.window.focus_window_top, { noremap = true, silent = true, desc = "window: Focus on the top window" })
vim.keymap.set("n", "<leader>l", actions.window.focus_window_right, { noremap = true, silent = true, desc = "window: Focus on the right window" })

-- buffer
vim.keymap.set("n", "<leader>1", actions.buffer.open_buffer_1, { noremap = true, silent = true, desc = "buffer: Open buffer 1" })
vim.keymap.set("n", "<leader>2", actions.buffer.open_buffer_2, { noremap = true, silent = true, desc = "buffer: Open buffer 2" })
vim.keymap.set("n", "<leader>3", actions.buffer.open_buffer_3, { noremap = true, silent = true, desc = "buffer: Open buffer 3" })
vim.keymap.set("n", "<leader>4", actions.buffer.open_buffer_4, { noremap = true, silent = true, desc = "buffer: Open buffer 4" })
vim.keymap.set("n", "<leader>5", actions.buffer.open_buffer_5, { noremap = true, silent = true, desc = "buffer: Open buffer 5" })
vim.keymap.set("n", "<leader>6", actions.buffer.open_buffer_6, { noremap = true, silent = true, desc = "buffer: Open buffer 6" })
vim.keymap.set("n", "<leader>7", actions.buffer.open_buffer_7, { noremap = true, silent = true, desc = "buffer: Open buffer 7" })
vim.keymap.set("n", "<leader>8", actions.buffer.open_buffer_8, { noremap = true, silent = true, desc = "buffer: Open buffer 8" })
vim.keymap.set("n", "<leader>9", actions.buffer.open_buffer_9, { noremap = true, silent = true, desc = "buffer: Open buffer 9" })
vim.keymap.set("n", "<leader>0", actions.buffer.open_buffer_10, { noremap = true, silent = true, desc = "buffer: Open buffer 10" })

-- fast resize
vim.keymap.set(
  "n",
  "<leader><C-Left>",
  actions.window.resize_window_vertical_minus,
  { noremap = true, silent = true, desc = "window: Resize -(v:count) vertically." }
)
vim.keymap.set(
  "n",
  "<leader><C-Down>",
  actions.window.resize_window_horizontal_minus,
  { noremap = true, silent = true, desc = "window: Resize -(v:count) horizontally." }
)
vim.keymap.set(
  "n",
  "<leader><C-Up>",
  actions.window.resize_window_horizontal_plus,
  { noremap = true, silent = true, desc = "window: Resize +(v:count) horizontally." }
)
vim.keymap.set(
  "n",
  "<leader><C-Right>",
  actions.window.resize_window_vertical_plus,
  { noremap = true, silent = true, desc = "window: Resize +(v:count) vertically." }
)

-------------------------------------------------

-- better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- better up/down
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "Next Search Result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "Prev Search Result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })

-- Clear search with <esc>
vim.keymap.set("n", "<Esc>", "<cmd>noh<cr><esc>", { noremap = true, silent = true, desc = "Remove search highlights" })

-- keywordprg
vim.keymap.set("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keywordprg" })

-- better format
-- https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
vim.keymap.set({ "n", "v" }, "=", "gq", { noremap = true, desc = "Format selected range" })
