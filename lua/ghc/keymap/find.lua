local finder = require("ghc.core.action.finder")

vim.keymap.set("n", "<leader>fb", finder.find_buffers, { noremap = true, desc = "Switch buffer" })
vim.keymap.set("n", "<leader>fE", finder.find_explorer_workspace, { noremap = true, desc = "File explorer (from workspace)" })
vim.keymap.set("n", "<leader>fe", finder.find_explorer_current, { noremap = true, desc = "File explorer (from current directory)" })
vim.keymap.set("n", "<leader>fF", finder.find_files_workspace, { noremap = true, desc = "Find files (workspace)" })
vim.keymap.set("n", "<leader>ff", finder.find_files_cwd, { noremap = true, desc = "Find files (cwd)" })
vim.keymap.set("n", "<leader>fg", finder.find_files_git, { noremap = true, desc = "Find files (git)" })
vim.keymap.set("n", "<leader>fn", "<cmd>enew<cr>", { noremap = true, desc = "New File" })

vim.keymap.set("n", "<leader>fR", finder.find_frecency_workspace, { noremap = true, desc = "Recent (repo)" })
vim.keymap.set("n", "<leader>fr", finder.find_frecency_cwd, { noremap = true, desc = "Recent (cwd)" })
vim.keymap.set("n", "<leader><leader>", finder.find_frecency_cwd, { noremap = true, desc = "Recent (cwd)" })
