local path = require("ghc.core.util.path")

local neo_tree = {
  file = {
    workspace = function()
      require("neo-tree.command").execute({
        dir = path.workspace(),
        toggle = true,
      })
    end,
    cwd = function()
      require("neo-tree.command").execute({
        dir = path.cwd(),
        toggle = true,
      })
    end,
  },
  buffer = {
    workspace = function()
      require("neo-tree.command").execute({
        source = "buffers",
        dir = path.workspace(),
        toggle = true,
      })
    end,
    cwd = function()
      require("neo-tree.command").execute({
        source = "buffers",
        dir = path.cwd(),
        toggle = true,
      })
    end,
  },
  git = {
    workspace = function()
      require("neo-tree.command").execute({
        source = "git_status",
        dir = path.workspace(),
        toggle = true,
      })
    end,
    cwd = function()
      require("neo-tree.command").execute({
        source = "git_status",
        dir = path.cwd(),
        toggle = true,
      })
    end,
  },
}

vim.keymap.set("n", "<leader>eE", neo_tree.file.workspace, { noremap = true, desc = "NeoTree files (workspace)" })
vim.keymap.set("n", "<leader>ee", neo_tree.file.cwd, { noremap = true, desc = "NeoTree files (cwd)" })
vim.keymap.set("n", "<leader>eB", neo_tree.buffer.workspace, { noremap = true, desc = "NeoTree buffers (workspace)" })
vim.keymap.set("n", "<leader>eb", neo_tree.buffer.cwd, { noremap = true, desc = "NeoTree buffers (cwd)" })
vim.keymap.set("n", "<leader>eG", neo_tree.git.workspace, { noremap = true, desc = "NeoTree git (workspace)" })
vim.keymap.set("n", "<leader>eg", neo_tree.git.cwd, { noremap = true, desc = "NeoTree git (cwd)" })
