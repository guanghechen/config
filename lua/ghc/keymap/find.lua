local paths = require("ghc.util.path").paths

local finder = {
  explorer = {
    workspace = function()
      require("telescope").extensions.file_browser.file_browser({
        cwd = paths.workspace(),
        workspace = "CWD",
        show_untracked = true,
        grouped = true,
        initial_mode = "normal",
        prompt_title = "File explorer",
      })
    end,
    current = function()
      require("telescope").extensions.file_browser.file_browser({
        cwd = paths.current(),
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
        cwd = paths.workspace(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find files (workspace)",
      })
    end,
    cwd = function()
      require("telescope.builtin").find_files({
        cwd = paths.cwd(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find files (cwd)",
      })
    end,
    git = function()
      require("telescope.builtin").git_files({
        cwd = paths.workspace(),
        workspace = "CWD",
        prompt_title = "Find files (git)",
      })
    end,
  },
  frecency = {
    workspace = function()
      require("telescope").extensions.frecency.frecency({
        cwd = paths.workspace(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (workspace)",
      })
    end,
    cwd = function()
      require("telescope").extensions.frecency.frecency({
        cwd = paths.cwd(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (cwd)",
      })
    end,
    current = function()
      require("telescope").extensions.frecency.frecency({
        cwd = paths.current(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Find recent (current directory)",
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
