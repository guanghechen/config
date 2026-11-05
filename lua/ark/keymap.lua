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
mk({ "n" }, "n", "'Nn'[v:searchforward].'zzzv'", "search: next result", true)
mk({ "x" }, "n", "'Nn'[v:searchforward]", "search: next result", true)
mk({ "o" }, "n", "'Nn'[v:searchforward]", "search: next result", true)
mk({ "n" }, "N", "'nN'[v:searchforward].'zzzv'", "search: prev result", true)
mk({ "x" }, "N", "'nN'[v:searchforward]", "search: prev result", true)
mk({ "o" }, "N", "'nN'[v:searchforward]", "search: prev result", true)

---! add undo break-points
mk({ "i" }, ",", ",<C-g>u")
mk({ "i" }, ".", ".<C-g>u")
mk({ "i" }, ";", ";<C-g>u")
-- An input method commits full-width punctuation, which the ASCII keys above do not catch.
mk({ "i" }, "，", "，<C-g>u")
mk({ "i" }, "。", "。<C-g>u")
mk({ "i" }, "；", "；<C-g>u")
mk({ "i" }, "：", "：<C-g>u")
mk({ "i" }, "！", "！<C-g>u")
mk({ "i" }, "？", "？<C-g>u")
-- As in VS Code, a line break and the first space after a word start a new undo step, so undo takes back a line or a
-- word with the space before it. blink.pairs replaces these two maps when it loads; era/plugin/blink-pairs.lua keeps
-- the break-points on its maps.
mk({ "i" }, "<cr>", "<C-g>u<cr>")
mk({ "i" }, "<space>", function()
  local col = vim.api.nvim_win_get_cursor(0)[2] ---@type integer
  local before = vim.api.nvim_get_current_line():sub(col, col) ---@type string
  return (before ~= "" and before:match("%s") == nil) and "<C-g>u<space>" or "<space>"
end, nil, true)

---! better copy/paste list
mk({ "i", "n", "x" }, { "<C-a>a", "<D-a>", "<M-a>" }, "<esc>ggVG", "system: select all")
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
-- mk({ "n" }, "J", "mzJ`z", "join: merge lines without moving cursor")
mk({ "x" }, "J", ":m '>+1<cr>gv=gv", "move: move lines down in visual selection")
mk({ "x" }, "K", ":m '<-2<cr>gv=gv", "move: move lines up in visual selection")

---! better jump list
mk({ "n", "x" }, "<C-i>", "<C-o>", "jump back")
mk({ "n", "x" }, "<C-o>", "<C-i>", "jump forward")
mk({ "i" }, "<C-i>", "<C-o><C-o>", "jump back")
mk({ "i" }, "<C-o>", "<C-o><C-i>", "jump forward")

---! commenting
mk({ "n" }, "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "comment: add below")
mk({ "n" }, "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "comment: add above")

---! enhancement
mk({ "i", "n", "x" }, "<esc>", function()
  vim.cmd("noh")
  local snippet = package.loaded["vim.snippet"]
  if snippet ~= nil then
    snippet.stop()
  end
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
