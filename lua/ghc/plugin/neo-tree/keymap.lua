local path = require("ghc.util.path")

local neo_tree = {
  file = {
    workspace = function()
      require("neo-tree.command").execute({
        action = "focus",
        source = "filesystem",
        dir = path.workspace(),
      })
    end,
    cwd = function()
      require("neo-tree.command").execute({
        action = "focus",
        source = "filesystem",
        dir = path.cwd(),
      })
    end,
  },
  buffer = {
    workspace = function()
      require("neo-tree.command").execute({
        action = "focus",
        source = "buffers",
        dir = path.workspace(),
      })
    end,
    cwd = function()
      require("neo-tree.command").execute({
        action = "focus",
        source = "buffers",
        dir = path.cwd(),
      })
    end,
  },
  git = {
    workspace = function()
      require("neo-tree.command").execute({
        action = "focus",
        source = "git_status",
        dir = path.workspace(),
      })
    end,
    cwd = function()
      require("neo-tree.command").execute({
        action = "focus",
        source = "git_status",
        dir = path.cwd(),
      })
    end,
  },
  reveal = function()
    local ft_current = vim.api.nvim_buf_get_option(0, "filetype")
    if ft_current == "neo-tree" then
      require("neo-tree.command").execute({
        action = "close",
      })
    else
      require("neo-tree.command").execute({
        action = "focus",
        source = "filesystem",
        reveal = true,
      })
    end
  end,
  focus = function()
    local ft_current = vim.api.nvim_buf_get_option(0, "filetype")
    if ft_current == "neo-tree" then
      require("neo-tree.command").execute({
        action = "close",
      })
    else
      require("neo-tree.command").execute({
        action = "focus",
        source = "last",
      })
    end
  end,
}

-- focus
vim.keymap.set("n", "<leader>eF", neo_tree.file.workspace, { noremap = true, desc = "Explorer files (workspace)" })
vim.keymap.set("n", "<leader>ef", neo_tree.file.cwd, { noremap = true, desc = "Explorer files (cwd)" })
vim.keymap.set("n", "<leader>eB", neo_tree.buffer.workspace, { noremap = true, desc = "Explorer buffers (workspace)" })
vim.keymap.set("n", "<leader>eb", neo_tree.buffer.cwd, { noremap = true, desc = "Explorer buffers (cwd)" })
vim.keymap.set("n", "<leader>eG", neo_tree.git.workspace, { noremap = true, desc = "Explorer git (workspace)" })
vim.keymap.set("n", "<leader>eg", neo_tree.git.cwd, { noremap = true, desc = "Explorer git (cwd)" })

-- reveal
vim.keymap.set("n", "<leader>ee", neo_tree.focus, { noremap = true, desc = "Explorer focus" })
vim.keymap.set("n", "<leader>er", neo_tree.reveal, { noremap = true, desc = "Explorer reveal" })
