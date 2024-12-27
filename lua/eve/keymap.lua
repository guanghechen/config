local command = require("eve.command")
local K = command.definitions ---@type eve.command.definitions

---@param modes                         string[]
---@param key                           string
---@param cmd                           string
---@param desc                          ?string
local function mk(modes, key, cmd, desc)
  vim.keymap.set(modes, key, cmd, {
    noremap = true,
    silent = true,
    nowait = true,
    desc = desc,
  })
end

---@param modes                         string[]
---@param key                           string
---@param definition                    eve.command.IDefinition|eve.command.IDefinitionWithCandidates
---@return nil
local function kk(modes, key, definition)
  vim.keymap.set(modes, key, function()
    vim.cmd(definition.uuid)
  end, {
    noremap = true,
    silent = true,
    nowait = true,
    desc = definition.desc,
  })
end

--#enhance------------------------------------------------------------------------------------------
---! better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

---! better up/down
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "down" })
vim.keymap.set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "down" })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "up" })
vim.keymap.set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "up" })

---! https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "search: next result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "search: next result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "search: next result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "search: prev result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "search: prev result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "search: prev result" })

---! commenting
mk({ "n" }, "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "comment: add below")
mk({ "n" }, "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "comment: add above")

---! enhancement
mk({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", "remove search highlights") -- Clear search with <esc>
mk({ "t" }, "<C-n>", "<C-\\><C-n>", "terminal: enter normal mode") -- Exit terminal

---! Add undo break-points
mk({ "i" }, ",", ",<c-g>u")
mk({ "i" }, ".", ".<c-g>u")
mk({ "i" }, ";", ";<c-g>u")
mk({ "i" }, "<", "<<c-g>u")
mk({ "i" }, "(", "(<c-g>u")
mk({ "i" }, "[", "[<c-g>u")
mk({ "i" }, "{", "{<c-g>u")
mk({ "i" }, "<cr>", "<cr><c-g>u")
mk({ "i" }, "<space>", "<space><c-g>u")

----- better jump list -----
mk({ "i", "n", "v" }, "<C-i>", "<C-o>", "jump back")
mk({ "i", "n", "v" }, "<C-o>", "<C-i>", "jump forward")

----- better copy/paste list -----
mk({ "i", "n", "v" }, "<C-a>a", "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "v" }, "<M-a>", "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "v" }, "<C-a>v", '<esc>"+p', "system: paste from clipboard")
mk({ "i", "n", "v" }, "<M-v>", '<esc>"+p', "system: paste from clipboard")
mk({ "v" }, "<C-a>c", '"+y', "system: copy to clipboard")
mk({ "v" }, "<M-c>", '"+y', "system: copy to clipboard")
mk({ "v" }, "<C-a>x", '"+x', "system: cut to clipboard")
mk({ "v" }, "<M-x>", '"+x', "system: cut to clipboard")
kk({ "n" }, "<C-a>c", K.copy.char_under_cursor)
kk({ "n" }, "<M-c>", K.copy.char_under_cursor)

--- quick access widgets (diagnostic, explorer, terminal) -----
kk({ "n", "t", "v" }, "<leader>`", K.ux.resume_last_widget)
kk({ "n", "v" }, "<leader>1", K.explorer.fs_cwd)
kk({ "n", "v" }, "<leader>2", K.search.files)
kk({ "n", "v" }, "<leader>3", K.explorer.git_cwd)
------------------------------------------------------------------------------------------#enhance--

--#[a]i---------------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>aa", K.ai.copilot_chat_toggle)
kk({ "n", "v" }, "<leader>ap", K.ai.copilot_chat_prompt)
kk({ "n", "v" }, "<leader>aq", K.ai.copilot_chat_quick)
kk({ "n", "v" }, "<leader>as", K.ai.copilot_chat_stop)
kk({ "n", "v" }, "<leader>ax", K.ai.copilot_chat_reset)
---------------------------------------------------------------------------------------------#[a]i--

--#[b]uf--------------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, "<C-a>s", K.buf.save)
kk({ "i", "n", "v" }, "<M-s>", K.buf.save)
kk({ "n", "v" }, "<leader>[", K.buf.focus_left)
kk({ "n", "v" }, "<leader>]", K.buf.focus_right)
kk({ "n", "v" }, "<leader>{", K.buf.swap_left)
kk({ "n", "v" }, "<leader>}", K.buf.swap_right)
kk({ "n", "v" }, "<leader>b[", K.buf.focus_left)
kk({ "n", "v" }, "<leader>b]", K.buf.focus_right)
kk({ "n", "v" }, "<leader>b{", K.buf.swap_left)
kk({ "n", "v" }, "<leader>b}", K.buf.swap_right)
kk({ "n", "v" }, "<leader>b1", K.buf.focus_1)
kk({ "n", "v" }, "<leader>b2", K.buf.focus_2)
kk({ "n", "v" }, "<leader>b3", K.buf.focus_3)
kk({ "n", "v" }, "<leader>b4", K.buf.focus_4)
kk({ "n", "v" }, "<leader>b5", K.buf.focus_5)
kk({ "n", "v" }, "<leader>b6", K.buf.focus_6)
kk({ "n", "v" }, "<leader>b7", K.buf.focus_7)
kk({ "n", "v" }, "<leader>b8", K.buf.focus_8)
kk({ "n", "v" }, "<leader>b9", K.buf.focus_9)
kk({ "n", "v" }, "<leader>b0", K.buf.focus_10)
kk({ "n", "v" }, "<leader>bd", K.buf.close)
kk({ "n", "v" }, "<leader>bh", K.buf.close_to_leftest)
kk({ "n", "v" }, "<leader>bl", K.buf.close_to_rightest)
kk({ "n", "v" }, "<leader>bn", K.buf.new)
kk({ "n", "v" }, "<leader>bo", K.buf.close_others)
kk({ "n", "v" }, "<leader>bp", K.buf.pin)
--------------------------------------------------------------------------------------------#[b]uf--

--#[c]ode-------------------------------------------------------------------------------------------
mk({ "n" }, "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "code: add comment below")
mk({ "n" }, "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "code: add comment above")
kk({ "i", "n", "v" }, "<F5>", K.code.run)
kk({ "n" }, "<leader>cs", K.code.swap_conditional_branches)
-------------------------------------------------------------------------------------------#[c]ode--

--#[c]opy-------------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, "<C-a>C", K.copy.filepath)
kk({ "i", "n", "v" }, "<M-C>", K.copy.filepath)
-----------------------------------------------------------------------------------------#[c]opy----

--#[d]ebug------------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>dd", K.debug.inspect)
kk({ "n", "v" }, "<leader>dI", K.debug.inspect_tree)
kk({ "n", "v" }, "<leader>di", K.debug.inspect_pos)
kk({ "n", "v" }, "<leader>ds", K.debug.inspect_state)
------------------------------------------------------------------------------------------#[d]ebug--

--#[e]xplorer---------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>ee", K.explorer.last)
kk({ "n", "v" }, "<leader>eF", K.explorer.fs_workspace)
kk({ "n", "v" }, "<leader>ef", K.explorer.fs_cwd)
kk({ "n", "v" }, "<leader>eG", K.explorer.git_workspace)
kk({ "n", "v" }, "<leader>eg", K.explorer.git_cwd)
kk({ "n", "v" }, "<leader>er", K.explorer.fs_reveal)
kk({ "n", "v" }, "<leader>et", K.explorer.toggle)
---------------------------------------------------------------------------------------#[e]xplorer--

--#[f]ind-------------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader><leader>", K.find.files)
kk({ "n", "v" }, "<leader>fb", K.find.buffers)
kk({ "n", "v" }, "<leader>fc", K.find.files_cwd)
kk({ "n", "v" }, "<leader>fe", K.find.explorer)
kk({ "n", "v" }, "<leader>fd", K.find.files_directory)
kk({ "n", "v" }, "<leader>ff", K.find.files)
kk({ "n", "v" }, "<leader>fg", K.find.git_not_committed)
kk({ "n", "v" }, "<leader>fh", K.find.highlights)
kk({ "n", "v" }, "<leader>fp", K.find.pinned_files)
kk({ "n", "v" }, "<leader>fv", K.find.vim_options)
kk({ "n", "v" }, "<leader>fw", K.find.files_workspace)
-------------------------------------------------------------------------------------------#[f]ind--

--#[g]it--------------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>gB", K.git.browse)
kk({ "n", "v" }, "<leader>gf", K.git.history_file)
kk({ "n", "v" }, "<leader>gG", K.git.history)
kk({ "n", "v" }, "<leader>gg", K.git.diffview)
--------------------------------------------------------------------------------------------#[g]it--

--#[q]uit-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>qq", "<cmd>qa<cr>", "quit: quit all")
kk({ "n", "v" }, "<leader>qL", K.session.restore_autosaved)
kk({ "n", "v" }, "<leader>ql", K.session.restore)
kk({ "n", "v" }, "<leader>qs", K.session.save)
-------------------------------------------------------------------------------------------#[q]uit--

--#[r]efresh----------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, "<C-a>r", K.refresh.all)
kk({ "i", "n", "v" }, "<M-r>", K.refresh.all)
---------------------------------------------------------------------------------------#[r]efresh---

--#[r]eplace----------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>rr", K.replace.files)
kk({ "n", "v" }, "<leader>rb", K.replace.files_in_buffer)
kk({ "n", "v" }, "<leader>rd", K.replace.files_in_directory)
kk({ "n", "v" }, "<leader>rc", K.replace.files_in_cwd)
kk({ "n", "v" }, "<leader>rw", K.replace.files_in_workspace)
---------------------------------------------------------------------------------------#[r]eplace---

--#[s]earch-----------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, "<C-a>f", K.search.files_in_buffer)
kk({ "i", "n", "v" }, "<M-f>", K.search.files_in_buffer)
kk({ "n", "v" }, "<leader>ss", K.search.files)
kk({ "n", "v" }, "<leader>sb", K.search.files_in_buffer)
kk({ "n", "v" }, "<leader>sc", K.search.files_in_cwd)
kk({ "n", "v" }, "<leader>sd", K.search.files_in_directory)
kk({ "n", "v" }, "<leader>sw", K.search.files_in_workspace)
-----------------------------------------------------------------------------------------#[s]earch--

--#[t]ab--------------------------------------------------------------------------------------------
kk({ "n", "v" }, "[t", K.tab.focus_left)
kk({ "n", "v" }, "]t", K.tab.focus_right)
kk({ "n", "v" }, "<leader>,", K.tab.focus_left)
kk({ "n", "v" }, "<leader>.", K.tab.focus_right)
kk({ "n", "v" }, "<leader>t[", K.tab.focus_left)
kk({ "n", "v" }, "<leader>t]", K.tab.focus_right)
kk({ "n", "v" }, "<leader>t1", K.tab.focus_1)
kk({ "n", "v" }, "<leader>t2", K.tab.focus_2)
kk({ "n", "v" }, "<leader>t3", K.tab.focus_3)
kk({ "n", "v" }, "<leader>t4", K.tab.focus_4)
kk({ "n", "v" }, "<leader>t5", K.tab.focus_5)
kk({ "n", "v" }, "<leader>t6", K.tab.focus_6)
kk({ "n", "v" }, "<leader>t7", K.tab.focus_7)
kk({ "n", "v" }, "<leader>t8", K.tab.focus_8)
kk({ "n", "v" }, "<leader>t9", K.tab.focus_9)
kk({ "n", "v" }, "<leader>t0", K.tab.focus_10)
kk({ "n", "v" }, "<leader>td", K.tab.close)
kk({ "n", "v" }, "<leader>th", K.tab.close_to_leftest)
kk({ "n", "v" }, "<leader>tl", K.tab.close_to_rightest)
kk({ "n", "v" }, "<leader>to", K.tab.close_others)
kk({ "n", "v" }, "<leader>tN", K.tab.new)
kk({ "n", "v" }, "<leader>tn", K.tab.new_with_buf)
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]erminal---------------------------------------------------------------------------------------
kk({ "i", "n", "t", "v" }, "<C-a>g", K.term.lazygit_cwd)
kk({ "i", "n", "t", "v" }, "<M-g>", K.term.lazygit_cwd)
kk({ "i", "n", "t", "v" }, "<C-a>t", K.term.toggle_cwd)
kk({ "i", "n", "t", "v" }, "<M-t>", K.term.toggle_cwd)
kk({ "n", "t" }, "<leader>tT", K.term.toggle_workspace)
kk({ "n", "t" }, "<leader>tt", K.term.toggle_cwd)
---------------------------------------------------------------------------------------#[t]erminal--

--#[t]oggle-----------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, "<C-a>T", K.toggle.theme_variant)
kk({ "i", "n", "v" }, "<M-T>", K.toggle.theme_variant)
kk({ "n", "v" }, "<leader>tF", K.toggle.flight)
kk({ "n", "v" }, "<leader>tR", K.toggle.relativenumber)
kk({ "n", "v" }, "<leader>tS", K.toggle.theme)
kk({ "n", "v" }, "<leader>tT", K.toggle.transparency)
kk({ "n", "v" }, "<leader>tt", K.toggle.list)
-----------------------------------------------------------------------------------------#[t]oggle--

--#[u]x---------------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>un", K.ux.dismiss_notifications)
---------------------------------------------------------------------------------------------#[u]x--

--#[w]in--------------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, "<C-a><Left>", K.win.resize_vertical_minus)
kk({ "i", "n", "v" }, "<C-a><Down>", K.win.resize_horizontal_minus)
kk({ "i", "n", "v" }, "<C-a><Up>", K.win.resize_horizontal_plus)
kk({ "i", "n", "v" }, "<C-a><Right>", K.win.resize_vertical_plus)
kk({ "i", "n", "v" }, "<M-Left>", K.win.resize_vertical_minus)
kk({ "i", "n", "v" }, "<M-Down>", K.win.resize_horizontal_minus)
kk({ "i", "n", "v" }, "<M-Up>", K.win.resize_horizontal_plus)
kk({ "i", "n", "v" }, "<M-Right>", K.win.resize_vertical_plus)
kk({ "i", "n", "v" }, "<C-a>i", K.win.history_backward)
kk({ "i", "n", "v" }, "<C-a>o", K.win.history_forward)
kk({ "i", "n", "v" }, "<M-i>", K.win.history_backward)
kk({ "i", "n", "v" }, "<M-o>", K.win.history_forward)
kk({ "i", "n", "t", "v" }, "<C-a>h", K.win.focus_left)
kk({ "i", "n", "t", "v" }, "<C-a>j", K.win.focus_bottom)
kk({ "i", "n", "t", "v" }, "<C-a>k", K.win.focus_top)
kk({ "i", "n", "t", "v" }, "<C-a>l", K.win.focus_right)
kk({ "i", "n", "t", "v" }, "<M-h>", K.win.focus_left)
kk({ "i", "n", "t", "v" }, "<M-j>", K.win.focus_bottom)
kk({ "i", "n", "t", "v" }, "<M-k>", K.win.focus_top)
kk({ "i", "n", "t", "v" }, "<M-l>", K.win.focus_right)
kk({ "n", "v" }, "<leader>wd", K.win.close)
kk({ "n", "v" }, "<leader>wh", K.win.history)
kk({ "n", "v" }, "<leader>wj", K.win.split_horizontal)
kk({ "n", "v" }, "<leader>wl", K.win.split_vertical)
kk({ "n", "v" }, "<leader>wo", K.win.close_others)
kk({ "n", "v" }, "<leader>wp", K.win.project)
kk({ "n", "v" }, "<leader>ws", K.win.swap)
kk({ "n", "v" }, "<leader>ww", K.win.focus)
kk({ "n", "v" }, "<leader>sj", K.win.scroll_down)
kk({ "n", "v" }, "<leader>sk", K.win.scroll_up)
--------------------------------------------------------------------------------------------#[w]in--

--#[x] diagnostic-----------------------------------------------------------------------------------

mk({ "n", "v" }, "<leader>xD", "<cmd>Trouble diagnostics toggle<cr>", "diagnostic: open diagnostics (workspace)")
mk(
  { "n", "v" },
  "<leader>xd",
  "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  "diagnostic: open diagnostics (document)"
)
mk({ "n", "v" }, "<leader>xL", "<cmd>Trouble loclist toggle<cr>", "diagnostic: open location list (Trouble)")
mk({ "n", "v" }, "<leader>xq", "<cmd>Trouble qflist toggle<cr>", "diagnostic: open quickfix list (Trouble)")
kk({ "n", "v" }, "[d", K.diagnostic.goto_prev)
kk({ "n", "v" }, "]d", K.diagnostic.goto_next)
kk({ "n", "v" }, "[e", K.diagnostic.goto_prev_error)
kk({ "n", "v" }, "]e", K.diagnostic.goto_next_error)
kk({ "n", "v" }, "[q", K.diagnostic.goto_prev_quickfix)
kk({ "n", "v" }, "]q", K.diagnostic.goto_next_quickfix)
kk({ "n", "v" }, "[w", K.diagnostic.goto_prev_warn)
kk({ "n", "v" }, "]w", K.diagnostic.goto_next_warn)
kk({ "n", "v" }, "<leader>xl", K.diagnostic.line)
kk({ "n", "v" }, "<leader>xo", K.diagnostic.outline)
-----------------------------------------------------------------------------------#[x] diagnostic--
