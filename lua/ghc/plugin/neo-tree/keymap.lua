local neo_tree = {
  toggle = {
    workspace = function()
      require("neo-tree.command").execute({
        dir = LazyVim.root(),
        toggle = true,
      })
    end,
    cwd = function()
      require("neo-tree.command").execute({
        dir = vim.uv.cwd(),
        toggle = true,
      })
    end,
  },
}

vim.keymap.set("n", "<leader>E", neo_tree.toggle.workspace, { noremap = true, desc = "NeoTree (workspace)" })
vim.keymap.set("n", "<leader>e", neo_tree.toggle.cwd, { noremap = true, desc = "NeoTree (cwd)" })

local function keys()
  return {
    { "<leader>E", neo_tree.toggle.workspace, desc = "NeoTree (workspace)" },
    { "<leader>e", neo_tree.toggle.cwd, desc = "NeoTree (cwd)" },
  }
end

return keys
