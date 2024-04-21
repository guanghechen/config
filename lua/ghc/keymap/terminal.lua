local path = require("ghc.core.util.path")

local function set_term_ft(id)
  local term = nil
  for _, item in pairs(vim.g.nvchad_terms) do
    if item.id == id then
      term = item
      break
    end
  end

  if term ~= nil then
    vim.bo[term.buf].filetype = "nvchad-term"
  end
end

local terminal = {
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
}

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { noremap = true, silent = true, desc = "terminal: Exit terminal mode" })
vim.keymap.set("n", "<leader>tT", terminal.workspace, { noremap = true, silent = true, desc = "terminal: toggle terminal (workspace)" })
vim.keymap.set("n", "<leader>tt", terminal.cwd, { noremap = true, silent = true, desc = "terminal: toggle terminal (cwd)" })