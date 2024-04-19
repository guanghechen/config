local path = require("ghc.util.path")

local searcher = {
  live_grep_with_args = {
    workspace = function()
      require("telescope").extensions.live_grep_args.live_grep_args({
        workspace = "CWD",
        cwd = path.workspace(),
        show_untracked = true,
        prompt_title = "Search grep with args (workspace)",
      })
    end,
    cwd = function()
      require("telescope").extensions.live_grep_args.live_grep_args({
        cwd = path.cwd(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Search grep with args (cwd)",
      })
    end,
    current = function()
      require("telescope").extensions.live_grep_args.live_grep_args({
        cwd = path.current(),
        workspace = "CWD",
        show_untracked = true,
        prompt_title = "Search grep with args (current directory)",
      })
    end,
  },
}

-- vim.keymap.set("n", "<leader>sg1", searcher.live_grep_with_args.workspace, { noremap = true, desc = "Grep (workspace)" })
-- vim.keymap.set("n", "<leader>sg2", searcher.live_grep_with_args.cwd, { noremap = false, desc = "Grep (cwd)" })
-- vim.keymap.set("n", "<leader>sg3", searcher.live_grep_with_args.current, { noremap = false, desc = "Grep (directory)" })
vim.keymap.set("n", "<leader>sG", searcher.live_grep_with_args.workspace, { noremap = true, desc = "Grep (workspace)" })
vim.keymap.set("n", "<leader>sg", searcher.live_grep_with_args.cwd, { noremap = false, desc = "Grep (cwd)" })
