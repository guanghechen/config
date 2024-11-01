---@param mode                          string | string[]
---@param key                           string
---@param action                        any
---@param desc                          string
---@param silent                        ?boolean
---@param nowait                        ?boolean
local function mk(mode, key, action, desc, silent, nowait)
  vim.keymap.set(mode, key, action, { noremap = true, silent = silent, nowait = nowait, desc = desc })
end

--#enhance------------------------------------------------------------------------------------------
---! better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

---! better up/down
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "down" })
vim.keymap.set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "down" })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "up" })
vim.keymap.set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "up" })

---! https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "next Search Result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "next Search Result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "next Search Result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "prev Search Result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "prev Search Result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "prev Search Result" })

--- quick access widgets (diagnostic, explorer, terminal)
mk({ "n", "v" }, "<leader>1", ghc.action.explorer.toggle_explorer_file_cwd, "explorer: files (cwd)")
mk({ "n", "v" }, "<leader>3", ghc.action.explorer.toggle_explorer_git_cwd, "explorer: git (cwd)")
---------------------------------------------------------------------------------------#enhance-----

--#[e]xplorer---------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>eB", ghc.action.explorer.toggle_explorer_buffer_workspace, "explorer: buffers (workspace)")
mk({ "n", "v" }, "<leader>eb", ghc.action.explorer.toggle_explorer_buffer_cwd, "explorer: buffers (cwd)")
mk({ "n", "v" }, "<leader>ee", ghc.action.explorer.toggle_explorer_last, "explorer: last")
mk({ "n", "v" }, "<leader>eF", ghc.action.explorer.toggle_explorer_file_workspace, "explorer: files (workspace)")
mk({ "n", "v" }, "<leader>ef", ghc.action.explorer.toggle_explorer_file_cwd, "explorer: files (cwd)")
mk({ "n", "v" }, "<leader>eG", ghc.action.explorer.toggle_explorer_git_workspace, "explorer: git (workspace)")
mk({ "n", "v" }, "<leader>eg", ghc.action.explorer.toggle_explorer_git_cwd, "explorer: git (cwd)")
mk({ "n", "v" }, "<leader>er", ghc.action.explorer.reveal_file_explorer, "explorer: reveal file")
mk({ "n", "v" }, "<leader>et", ghc.action.explorer.toggle_explorers, "explorer: toggle")
---------------------------------------------------------------------------------------#[e]xplorer--
