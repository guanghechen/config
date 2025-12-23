---@param modes                         string[]
---@param keys                          string|string[]
---@param cmd                           string|fun(): string|nil
---@param desc                          ?string
---@param expr                          ?boolean
---@return nil
local function mk(modes, keys, cmd, desc, expr)
  ---@type vim.keymap.set.Opts
  local opts = {
    noremap = true,
    silent = true,
    nowait = true,
    desc = desc,
    expr = expr,
  }

  if type(keys) == "string" then
    vim.keymap.set(modes, keys, cmd, opts)
  else
    for _, key in ipairs(keys) do
      vim.keymap.set(modes, key, cmd, opts)
    end
  end
end

-- Leader Key --------------------------------------------------------------------------------------

vim.g.mapleader = " "
vim.g.maplocalleader = " "

---! https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
mk({ "n" }, "n", "'Nn'[v:searchforward].'zv'", "search: next result", true)
mk({ "x" }, "n", "'Nn'[v:searchforward]", "search: next result", true)
mk({ "o" }, "n", "'Nn'[v:searchforward]", "search: next result", true)
mk({ "n" }, "N", "'nN'[v:searchforward].'zv'", "search: prev result", true)
mk({ "x" }, "N", "'nN'[v:searchforward]", "search: prev result", true)
mk({ "o" }, "N", "'nN'[v:searchforward]", "search: prev result", true)

---! add undo break-points
mk({ "i" }, ",", ",<C-g>u")
mk({ "i" }, ".", ".<C-g>u")
mk({ "i" }, ";", ";<C-g>u")
mk({ "i" }, "<", "<<C-g>u")
mk({ "i" }, "(", "(<C-g>u")
mk({ "i" }, "[", "[<C-g>u")
mk({ "i" }, "{", "{<C-g>u")
mk({ "i" }, "<cr>", "<cr><C-g>u")
mk({ "i" }, "<space>", "<space><C-g>u")

---! better copy/paste list
mk({ "i", "n", "x" }, { "<C-a>a", "<D-a>", "<M-a>" }, "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "x" }, { "<C-a>v", "<D-v>", "<M-v>" }, '<esc>"+p', "system: paste from clipboard")
mk({ "x" }, { "<C-a>c", "<D-c>", "<M-c>" }, '"+y', "system: copy to clipboard")
mk({ "x" }, { "<C-a>x", "<D-x>", "<M-x>" }, '"+x', "system: cut to clipboard")

---! better indenting
mk({ "x" }, "<", "<gv")
mk({ "x" }, ">", ">gv")

---! better up/down
mk({ "n", "x" }, { "j", "<Down>" }, "v:count == 0 ? 'gj' : 'j'", "navigate: down", true)
mk({ "n", "x" }, { "k", "<Up>" }, "v:count == 0 ? 'gk' : 'k'", "navigate: up", true)
mk({ "n", "x" }, "<C-j>", "<C-d>zz", "scroll: half page down and center")
mk({ "n", "x" }, "<C-k>", "<C-u>zz", "scroll: half page up and center")

---! better join/move
mk({ "n" }, "J", "mzJ`z", "join: merge lines without moving cursor")
mk({ "v" }, "J", ":m '>+1<cr>gv=gv", "move: move lines down in visual selection")
mk({ "v" }, "K", ":m '<-2<cr>gv=gv", "move: move lines up in visual selection")

---! better jump list
mk({ "i", "n", "x" }, "<C-i>", "<C-o>", "jump back")
mk({ "i", "n", "x" }, "<C-o>", "<C-i>", "jump forward")

---! commenting
mk({ "n" }, "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "comment: add below")
mk({ "n" }, "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "comment: add above")

---! enhancement
mk({ "i", "n", "x" }, "<esc>", function()
  vim.cmd("noh")
  vim.snippet.stop()
  return "<esc>"
end, "system: clear search highlights", true)
-- mk({ "t" }, { "<C-a>i", "<M-i>", "<D-i>" }, "<C-\\><C-n>", "system: enter normal mode") -- Exit terminal
mk({ "t" }, { "<C-i>" }, "<C-\\><C-n>", "system: enter normal mode") -- Exit terminal
mk({ "t" }, "<Tab>", function()
  return vim.api.nvim_replace_termcodes("<Tab>", true, false, true)
end, "terminal: insert tab", true)

---! z-prefixed scrolling
mk({ "n", "x" }, "zh", "zs", "scroll: line to left")
mk({ "n", "x" }, "zl", "ze", "scroll: line to right")
mk({ "n", "x" }, "zj", "zb", "scroll: line to bottom")
mk({ "n", "x" }, "zk", "zt", "scroll: line to top")

---! quit
mk({ "n", "x" }, "<leader>qq", "<cmd>qa<cr>", "quit: quit all")
