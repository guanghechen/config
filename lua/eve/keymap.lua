local mk = eve.nvim.make_keys

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
mk({ "i", "n", "v" }, { "<C-a>a", "<D-a>", "<M-a>" }, "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "v" }, { "<C-a>v", "<D-v>", "<M-v>" }, '<esc>"+p', "system: paste from clipboard")
mk({ "v" }, { "<C-a>c", "<D-c>", "<M-c>" }, '"+y', "system: copy to clipboard")
mk({ "v" }, { "<C-a>x", "<D-x>", "<M-x>" }, '"+x', "system: cut to clipboard")

---! better indenting
mk({ "v" }, "<", "<gv")
mk({ "v" }, ">", ">gv")

---! better up/down
mk({ "n", "x" }, { "j", "<Down>" }, "v:count == 0 ? 'gj' : 'j'", "navigate: down", true)
mk({ "n", "x" }, { "k", "<Up>" }, "v:count == 0 ? 'gk' : 'k'", "navigate: up", true)

---! better jump list
mk({ "i", "n", "v" }, "<C-i>", "<C-o>", "jump back")
mk({ "i", "n", "v" }, "<C-o>", "<C-i>", "jump forward")

---! commenting
mk({ "n" }, "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "comment: add below")
mk({ "n" }, "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "comment: add above")

---! enhancement
mk({ "i", "n", "s" }, "<esc>", function()
  local searching = eve.state.status.searching:snapshot() ---@type boolean
  if searching then
    eve.state.status.searching:next(false)
    vim.schedule(function()
      vim.cmd.noh()
      local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
      for _, bufnr in ipairs(bufnrs) do
        vim.api.nvim_buf_clear_namespace(bufnr, eve.constant.nsnr.search_count, 0, -1)
      end
    end)
  end
  if vim.snippet then
    vim.snippet.stop()
  end
  return "<esc>"
end, "system: clear search highlights", true)
mk({ "n", "v" }, "<leader>:", "q:", "system: open command line window")
mk({ "t" }, "<C-n>", "<C-\\><C-n>", "system: enter normal mode") -- Exit terminal

---! quit
mk({ "n", "v" }, "<leader>qq", "<cmd>qa<cr>", "quit: quit all")
