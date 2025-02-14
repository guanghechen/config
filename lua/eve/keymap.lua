local command = require("eve.command")
local K = command.definitions ---@type eve.command.definitions

---@param modes                         string[]
---@param keys                          string|string[]
---@param cmd                           string
---@param desc                          ?string
local function mk(modes, keys, cmd, desc)
  ---@type vim.keymap.set.Opts
  local opts = {
    noremap = true,
    silent = true,
    nowait = true,
    desc = desc,
  }

  if type(keys) == "string" then
    vim.keymap.set(modes, keys, cmd, opts)
  else
    for _, key in ipairs(keys) do
      vim.keymap.set(modes, key, cmd, opts)
    end
  end
end

---@param modes                         string[]
---@param keys                          string|string[]
---@param definition                    eve.command.IDefinition|eve.command.IDefinitionWithCandidates
---@return nil
local function kk(modes, keys, definition)
  ---@return nil
  local function callback()
    vim.cmd(definition.uuid)
  end

  ---@type vim.keymap.set.Opts
  local opts = {
    noremap = true,
    silent = true,
    nowait = true,
    desc = definition.desc,
  }

  if type(keys) == "string" then
    vim.keymap.set(modes, keys, callback, opts)
  else
    for _, key in ipairs(keys) do
      vim.keymap.set(modes, key, callback, opts)
    end
  end
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
mk({ "n", "v" }, "<leader>:", "q:", "system: open command line window")
mk({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", "system: remove search highlights") -- Clear search with <esc>
mk({ "t" }, "<C-n>", "<C-\\><C-n>", "system: enter normal mode") -- Exit terminal

---! Add undo break-points
mk({ "i" }, ",", ",<C-g>u")
mk({ "i" }, ".", ".<C-g>u")
mk({ "i" }, ";", ";<C-g>u")
mk({ "i" }, "<", "<<C-g>u")
mk({ "i" }, "(", "(<C-g>u")
mk({ "i" }, "[", "[<C-g>u")
mk({ "i" }, "{", "{<C-g>u")
mk({ "i" }, "<cr>", "<cr><C-g>u")
mk({ "i" }, "<space>", "<space><C-g>u")

----- better jump list -----
mk({ "i", "n", "v" }, "<C-i>", "<C-o>", "jump back")
mk({ "i", "n", "v" }, "<C-o>", "<C-i>", "jump forward")

----- better copy/paste list -----
mk({ "i", "n", "v" }, { "<C-a>a", "<D-a>", "<M-a>" }, "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "v" }, { "<C-a>v", "<D-v>", "<M-v>" }, '<esc>"+p', "system: paste from clipboard")
mk({ "v" }, { "<C-a>c", "<D-c>", "<M-c>" }, '"+y', "system: copy to clipboard")
mk({ "v" }, { "<C-a>x", "<D-x>", "<M-x>" }, '"+x', "system: cut to clipboard")
kk({ "n" }, { "<C-a>c", "<D-c>", "<M-c>" }, K.copy.char_under_cursor)

--- quick access widgets (diagnostic, explorer, terminal) -----
kk({ "n", "t", "v" }, "<leader>`", K.ux.resume_last_widget)
kk({ "n", "v" }, "<leader>;", K.ai.copilot_chat_toggle)
kk({ "n", "v" }, "<leader>'", K.ai.avante_ask)
kk({ "n", "v" }, "<leader>1", K.explorer.fs_cwd)
kk({ "n", "v" }, "<leader>2", K.term.yazi_reveal)
kk({ "n", "v" }, "<leader>3", K.explorer.git_cwd)
------------------------------------------------------------------------------------------#enhance--

--#[a]i---------------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>aa", K.ai.avante_ask)
kk({ "n", "v" }, "<leader>ae", K.ai.avante_edit)
kk({ "n", "v" }, "<leader>ar", K.ai.avante_refresh)

kk({ "n", "v" }, "<leader>ac", K.ai.copilot_chat_toggle)
kk({ "n", "v" }, "<leader>ap", K.ai.copilot_chat_prompt)
kk({ "n", "v" }, "<leader>aq", K.ai.copilot_chat_quick)
kk({ "n", "v" }, "<leader>aS", K.ai.copilot_chat_stop)
kk({ "n", "v" }, "<leader>aX", K.ai.copilot_chat_reset)
---------------------------------------------------------------------------------------------#[a]i--

--#[b]uf--------------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, { "<C-a>s", "<D-s>", "<M-s>" }, K.buf.save)
kk({ "n", "v" }, "<leader>[", K.buf.focus_left)
kk({ "n", "v" }, "<leader>]", K.buf.focus_right)
kk({ "n", "v" }, "<leader>{", K.buf.swap_left)
kk({ "n", "v" }, "<leader>}", K.buf.swap_right)
kk({ "n", "v" }, "<leader>b[", K.buf.focus_left)
kk({ "n", "v" }, "<leader>b]", K.buf.focus_right)
kk({ "n", "v" }, "<leader>b{", K.buf.swap_left)
kk({ "n", "v" }, "<leader>b}", K.buf.swap_right)
kk({ "n", "v" }, "<leader>b01", K.buf.focus_01)
kk({ "n", "v" }, "<leader>b02", K.buf.focus_02)
kk({ "n", "v" }, "<leader>b03", K.buf.focus_03)
kk({ "n", "v" }, "<leader>b04", K.buf.focus_04)
kk({ "n", "v" }, "<leader>b05", K.buf.focus_05)
kk({ "n", "v" }, "<leader>b06", K.buf.focus_06)
kk({ "n", "v" }, "<leader>b07", K.buf.focus_07)
kk({ "n", "v" }, "<leader>b08", K.buf.focus_08)
kk({ "n", "v" }, "<leader>b09", K.buf.focus_09)
kk({ "n", "v" }, "<leader>b10", K.buf.focus_10)
kk({ "n", "v" }, "<leader>b11", K.buf.focus_11)
kk({ "n", "v" }, "<leader>b12", K.buf.focus_12)
kk({ "n", "v" }, "<leader>b13", K.buf.focus_13)
kk({ "n", "v" }, "<leader>b14", K.buf.focus_14)
kk({ "n", "v" }, "<leader>b15", K.buf.focus_15)
kk({ "n", "v" }, "<leader>b16", K.buf.focus_16)
kk({ "n", "v" }, "<leader>b17", K.buf.focus_17)
kk({ "n", "v" }, "<leader>b18", K.buf.focus_18)
kk({ "n", "v" }, "<leader>b19", K.buf.focus_19)
kk({ "n", "v" }, "<leader>b20", K.buf.focus_10)
kk({ "n", "v" }, "<leader>b21", K.buf.focus_21)
kk({ "n", "v" }, "<leader>b22", K.buf.focus_22)
kk({ "n", "v" }, "<leader>b23", K.buf.focus_23)
kk({ "n", "v" }, "<leader>b24", K.buf.focus_24)
kk({ "n", "v" }, "<leader>b25", K.buf.focus_25)
kk({ "n", "v" }, "<leader>b26", K.buf.focus_26)
kk({ "n", "v" }, "<leader>b27", K.buf.focus_27)
kk({ "n", "v" }, "<leader>b28", K.buf.focus_28)
kk({ "n", "v" }, "<leader>b29", K.buf.focus_29)
kk({ "n", "v" }, "<leader>b30", K.buf.focus_30)
kk({ "n", "v" }, "<leader>b31", K.buf.focus_31)
kk({ "n", "v" }, "<leader>b32", K.buf.focus_32)
kk({ "n", "v" }, "<leader>b33", K.buf.focus_33)
kk({ "n", "v" }, "<leader>b34", K.buf.focus_34)
kk({ "n", "v" }, "<leader>b35", K.buf.focus_35)
kk({ "n", "v" }, "<leader>b36", K.buf.focus_36)
kk({ "n", "v" }, "<leader>b37", K.buf.focus_37)
kk({ "n", "v" }, "<leader>b38", K.buf.focus_38)
kk({ "n", "v" }, "<leader>b39", K.buf.focus_39)
kk({ "n", "v" }, "<leader>b40", K.buf.focus_40)
kk({ "n", "v" }, "<leader>b41", K.buf.focus_41)
kk({ "n", "v" }, "<leader>b42", K.buf.focus_42)
kk({ "n", "v" }, "<leader>b43", K.buf.focus_43)
kk({ "n", "v" }, "<leader>b44", K.buf.focus_44)
kk({ "n", "v" }, "<leader>b45", K.buf.focus_45)
kk({ "n", "v" }, "<leader>b46", K.buf.focus_46)
kk({ "n", "v" }, "<leader>b47", K.buf.focus_47)
kk({ "n", "v" }, "<leader>b48", K.buf.focus_48)
kk({ "n", "v" }, "<leader>b49", K.buf.focus_49)
kk({ "n", "v" }, "<leader>ba", K.find.bufs)
kk({ "n", "v" }, "<leader>bb", K.find.bufs_file)
kk({ "n", "v" }, "<leader>bd", K.buf.close)
kk({ "n", "v" }, "<leader>bh", K.buf.close_to_leftest)
kk({ "n", "v" }, "<leader>bl", K.buf.close_to_rightest)
kk({ "n", "v" }, "<leader>bn", K.buf.new)
kk({ "n", "v" }, "<leader>bo", K.buf.close_others)
kk({ "n", "v" }, "<leader>bp", K.buf.pin)
kk({ "n", "v" }, "<leader>bt", K.find.bufs_term)
--------------------------------------------------------------------------------------------#[b]uf--

--#[c]ode-------------------------------------------------------------------------------------------
mk({ "n" }, "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "code: add comment below")
mk({ "n" }, "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", "code: add comment above")
kk({ "i", "n", "v" }, "<F5>", K.code.run)
kk({ "i", "n", "v" }, "<F17>", K.code.run_force) -- F5 mapped to F17
kk({ "n" }, "<leader>cs", K.code.swap_conditional_branches)
-------------------------------------------------------------------------------------------#[c]ode--

--#[c]opy-------------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, { "<C-a>C", "<D-C>", "<M-C>" }, K.copy.filepath)
-----------------------------------------------------------------------------------------#[c]opy----

--#[d]ebug------------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>ii", K.debug.inspect_pos)
kk({ "n", "v" }, "<leader>is", K.debug.inspect_state)
kk({ "n", "v" }, "<leader>it", K.debug.inspect_tree)
kk({ "n", "v" }, "<leader>iw", K.debug.inspect_window)
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
kk({ "n", "v" }, "<leader>fb", K.find.bufs)
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

--#[p] clipboard------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, "<leader>pp", K.clipboard.paste)
------------------------------------------------------------------------------------#[p] clipboard--

--#[r]efresh----------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, { "<C-a>r", "<D-r>", "<M-r>" }, K.refresh.all)
---------------------------------------------------------------------------------------#[r]efresh---

--#[r]eplace----------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>rr", K.replace.files)
kk({ "n", "v" }, "<leader>rb", K.replace.files_in_buffer)
kk({ "n", "v" }, "<leader>rd", K.replace.files_in_directory)
kk({ "n", "v" }, "<leader>rc", K.replace.files_in_cwd)
kk({ "n", "v" }, "<leader>rw", K.replace.files_in_workspace)
---------------------------------------------------------------------------------------#[r]eplace---

--#[s]earch-----------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, { "<C-a>f", "<D-f>", "<M-f>" }, K.search.files_in_buffer)
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
kk({ "i", "n", "t", "v" }, { "<C-a>g", "<D-g>", "<M-g>" }, K.term.lazygit_cwd)
kk({ "i", "n", "t", "v" }, { "<C-a>t", "<D-t>", "<M-t>" }, K.term.toggle_cwd)
kk({ "i", "n", "t", "v" }, { "<C-a>y", "<D-y>", "<M-y>" }, K.term.yazi_cwd)
---------------------------------------------------------------------------------------#[t]erminal--

--#[t]oggle-----------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, { "<C-a>T", "<D-T>", "<M-T>" }, K.toggle.theme_variant)
kk({ "n", "v" }, "<leader>tF", K.toggle.flight)
kk({ "n", "v" }, "<leader>tM", K.toggle.markdown)
kk({ "n", "v" }, "<leader>tR", K.toggle.relativenumber)
kk({ "n", "v" }, "<leader>tS", K.toggle.theme)
kk({ "n", "v" }, "<leader>tT", K.toggle.transparency)
kk({ "n", "v" }, "<leader>tt", K.toggle.list)
kk({ "n", "v" }, "<leader>tU", K.toggle.username)
kk({ "n", "v" }, "<leader>z", K.toggle.maximize)
-----------------------------------------------------------------------------------------#[t]oggle--

--#[u]x---------------------------------------------------------------------------------------------
kk({ "n", "v" }, "<leader>un", K.ux.dismiss_notifications)
---------------------------------------------------------------------------------------------#[u]x--

--#[w]in--------------------------------------------------------------------------------------------
kk({ "i", "n", "v" }, { "<C-a><Left>", "<D-Left>", "<M-Left>" }, K.win.resize_vertical_minus)
kk({ "i", "n", "v" }, { "<C-a><Down>", "<D-Down>", "<M-Down>" }, K.win.resize_horizontal_minus)
kk({ "i", "n", "v" }, { "<C-a><Up>", "<D-Up>", "<M-Up>" }, K.win.resize_horizontal_plus)
kk({ "i", "n", "v" }, { "<C-a><Right>", "<D-Right>", "<M-Right>" }, K.win.resize_vertical_plus)
kk({ "i", "n", "v" }, { "<C-a>i", "<D-i>", "<M-i>" }, K.win.history_backward)
kk({ "i", "n", "v" }, { "<C-a>o", "<D-o>", "<M-o>" }, K.win.history_forward)
kk({ "i", "n", "t", "v" }, { "<C-a>h", "<D-h>", "<M-h>" }, K.win.focus_left)
kk({ "i", "n", "t", "v" }, { "<C-a>j", "<D-j>", "<M-j>" }, K.win.focus_bottom)
kk({ "i", "n", "t", "v" }, { "<C-a>k", "<D-k>", "<M-k>" }, K.win.focus_top)
kk({ "i", "n", "t", "v" }, { "<C-a>l", "<D-l>", "<M-l>" }, K.win.focus_right)
kk({ "n", "v" }, "<leader>wd", K.win.close)
kk({ "n", "v" }, "<leader>wh", K.win.history)
kk({ "n", "v" }, "<leader>wk", K.win.split_above)
kk({ "n", "v" }, "<leader>wl", K.win.split_right)
kk({ "n", "v" }, "<leader>wj", K.win.split_below)
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
