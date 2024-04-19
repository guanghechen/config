local path = require("ghc.util.path")

local finder = {
  explorer = {
    workspace = function()
      require("telescope").extensions.file_browser.file_browser({
        cwd = path.workspace(),
        workspace = "CWD",
        show_untracked = true,
        grouped = true,
        initial_mode = "normal",
        prompt_title = "File explorer",
      })
    end,
    current = function()
      require("telescope").extensions.file_browser.file_browser({
        cwd = path.current(),
        workspace = "CWD",
        select_buffer = true,
        show_untracked = true,
        grouped = true,
        initial_mode = "normal",
        prompt_title = "File explorer",
      })
    end,
  },
  files = {
    workspace = function()
      require("telescope.builtin").find_files({
        cwd = path.workspace(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find files (workspace)",
      })
    end,
    cwd = function()
      require("telescope.builtin").find_files({
        cwd = path.cwd(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find files (cwd)",
      })
    end,
    git = function()
      require("telescope.builtin").git_files({
        workspace = "CWD",
        cwd = path.workspace(),
        prompt_title = "Find files (git)",
      })
    end,
  },
  frecency = {
    workspace = function()
      require("telescope").extensions.frecency.frecency({
        cwd = path.workspace(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (workspace)",
      })
    end,
    cwd = function()
      require("telescope").extensions.frecency.frecency({
        cwd = path.cwd(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (cwd)",
      })
    end,
    current = function()
      require("telescope").extensions.frecency.frecency({
        cwd = path.current(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (current directory)",
      })
    end,
  },
  terminal = {
    workspace = function()
      LazyVim.terminal(nil, {
        cwd = path.workspace(),
        border = "rounded",
        persistent = true,
      })
    end,
    cwd = function()
      LazyVim.terminal(nil, {
        cwd = path.cwd(),
        border = "rounded",
        persistent = true,
      })
    end,
    current = function()
      LazyVim.terminal(nil, {
        cwd = path.current(),
        border = "rounded",
      })
    end,
  },
}

vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>", { noremap = true, desc = "Switch buffer" })
vim.keymap.set("n", "<leader>fE", finder.explorer.workspace, { noremap = true, desc = "File explorer (from workspace)" })
vim.keymap.set("n", "<leader>fe", finder.explorer.current, { noremap = true, desc = "File explorer (from current file)" })
vim.keymap.set("n", "<leader>fF", finder.files.workspace, { noremap = true, desc = "Find files (workspace)" })
vim.keymap.set("n", "<leader>ff", finder.files.cwd, { noremap = true, desc = "Find files (directory)" })
vim.keymap.set("n", "<leader>fg", finder.files.git, { noremap = true, desc = "Find files (git)" })
vim.keymap.set("n", "<leader><leader>", finder.files.cwd, { noremap = true, desc = "Find files (cwd)" })
-- vim.keymap.set("n", "<leader>fr1", finder.frecency.workspace, { noremap = true, desc = "Recent (repo)" })
-- vim.keymap.set("n", "<leader>fr2", finder.frecency.cwd, { noremap = true, desc = "Recent (cwd)" })
-- vim.keymap.set("n", "<leader>fr3", finder.frecency.current, { noremap = true, desc = "Recent (directory)" })
vim.keymap.set("n", "<leader>fR", finder.frecency.workspace, { noremap = true, desc = "Recent (repo)" })
vim.keymap.set("n", "<leader>fr", finder.frecency.cwd, { noremap = true, desc = "Recent (cwd)" })
vim.keymap.set("n", "<leader>ft1", finder.terminal.workspace, { noremap = true, desc = "Find files (workspace)" })
vim.keymap.set("n", "<leader>ft2", finder.terminal.cwd, { noremap = true, desc = "Find files (cwd)" })
vim.keymap.set("n", "<leader>ft3", finder.terminal.current, { noremap = true, desc = "Open terminal (directory)" })
