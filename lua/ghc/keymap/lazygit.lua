local function openLazyGitOnRootDir()
  LazyVim.lazygit({ cwd = LazyVim.root.git() })
end

local function openLazyGitOnCwd()
  LazyVim.lazygit()
end

local function openLazyGitWithCurrentFileHistory()
  local git_path = vim.api.nvim_buf_get_name(0)
  LazyVim.lazygit({ args = { "-f", vim.trim(git_path) } })
end

vim.keymap.set("n", "<leader>gg", openLazyGitOnRootDir, { desc = "Lazygit (Root Dir)" })
vim.keymap.set("n", "<leader>gG", openLazyGitOnCwd, { desc = "Lazygit (cwd)" })
vim.keymap.set("n", "<leader>gf", openLazyGitWithCurrentFileHistory, { desc = "Lazygit Current File History" })
