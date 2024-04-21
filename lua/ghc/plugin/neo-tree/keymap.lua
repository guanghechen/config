local path = require("ghc.core.util.path")

local neo_tree = {
  toggle = {
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
}

-- vim.keymap.set("n", "<leader>E", neo_tree.toggle.workspace, { noremap = true, desc = "NeoTree (workspace)" })
vim.keymap.set("n", "<leader>e", neo_tree.toggle.cwd, { noremap = true, desc = "NeoTree (cwd)" })
