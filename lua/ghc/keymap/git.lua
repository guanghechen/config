local path = require("ghc.core.util.path")

local git = {
  open = {
    workspace = function()
      LazyVim.lazygit({
        cwd = path.workspace(),
      })
    end,
    cwd = function()
      LazyVim.lazygit({
        cwd = path.cwd(),
      })
    end,
  },
  file = {
    history = function()
      local git_path = vim.api.nvim_buf_get_name(0)
      LazyVim.lazygit({
        args = {
          "-f",
          vim.trim(git_path)
        }
      })
    end,
  },
}

vim.keymap.set("n", "<leader>gG", git.open.workspace, { desc = "Lazygit (workspace)" })
vim.keymap.set("n", "<leader>gg", git.open.workspace, { desc = "Lazygit (cwd)" })
vim.keymap.set("n", "<leader>gf", git.file.history, { desc = "Lazygit Current File History" })
