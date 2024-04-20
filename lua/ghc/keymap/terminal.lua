local paths = require("ghc.util.path").paths

local terminal = {
  workspace = function()
    require("nvchad.term").toggle({
      pos = "float",
      id = "workspace-terminal",
      cmd = "cd " .. '"' .. paths.workspace() .. '"',
    })
  end,
  cwd = function()
    require("nvchad.term").toggle({
      pos = "float",
      id = "cwd-terminal",
      cmd = "cd " .. '"' .. paths.cwd() .. '"',
    })
  end,
  current = function()
    require("nvchad.term").create({
      pos = "float",
      id = "current-terminal",
      cmd = "cd " .. '"' .. paths.current() .. '"',
    })
  end,
}

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { noremap = true, silent = true, desc = "terminal: Exit terminal mode" })
vim.keymap.set("n", "<leader>T", terminal.workspace, { noremap = true, silent = true, desc = "terminal: toggle terminal (workspace)" })
vim.keymap.set("n", "<leader>t", terminal.cwd, { noremap = true, silent = true, desc = "terminal: toggle terminal (cwd)" })
