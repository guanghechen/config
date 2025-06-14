local mk = eve.nvim.make_keys
local ms = eve.nvim.make_shortcut
local K = eve.command.definitions ---@type eve.builtin.command.definitions

vim.cmd.menu(("PopUp.%s :%s<cr>"):format("Add\\ word\\ to\\ cspell", K.lint.spellcheck_register.uuid)) --action is like map-rhs

--#enhance------------------------------------------------------------------------------------------
----- better copy/paste list -----
ms({ "n" }, { "<C-a>c", "<D-c>", "<M-c>" }, K.copy.char_under_cursor)

--- quick access widgets (diagnostic, explorer, terminal) -----
ms({ "i", "n", "t", "v" }, { "<C-a>0", "<D-0>", "<M-0>" }, K.ux.resume_last_widget)
ms({ "n", "v" }, "<leader>`", K.ux.resume_last_widget)
ms({ "n", "v" }, "<leader>;", K.ai.copilot_chat_toggle)
ms({ "n", "v" }, "<leader>'", K.ai.avante_ask)
ms({ "n", "v" }, "<leader>1", K.explorer.fs_cwd)
ms({ "n", "v" }, "<leader>2", K.search.files_in_cwd)
ms({ "n", "v" }, "<leader>3", K.find.git_not_committed)
ms({ "n", "v" }, "<leader>4", K.explorer.git_cwd)
------------------------------------------------------------------------------------------#enhance--

--#[a]i---------------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>aa", K.ai.avante_ask)
ms({ "n", "v" }, "<leader>ae", K.ai.avante_edit)
ms({ "n", "v" }, "<leader>ar", K.ai.avante_refresh)

ms({ "n", "v" }, "<leader>ap", K.ai.copilot_chat_prompt)
ms({ "n", "v" }, "<leader>aq", K.ai.copilot_chat_quick)
ms({ "n", "v" }, "<leader>at", K.ai.copilot_chat_translate)
ms({ "n", "v" }, "<leader>aS", K.ai.copilot_chat_stop)
ms({ "n", "v" }, "<leader>aX", K.ai.copilot_chat_reset)
---------------------------------------------------------------------------------------------#[a]i--

--#[b]uf--------------------------------------------------------------------------------------------
ms({ "i", "n", "v" }, { "<C-a>s", "<D-s>", "<M-s>" }, K.buf.save)
ms({ "i", "n", "v" }, { "<C-a>w", "<D-w>", "<M-w>" }, K.buf.close)
ms({ "n", "v" }, "[b", K.buf.focus_left)
ms({ "n", "v" }, "[1", K.buf.focus_left_1)
ms({ "n", "v" }, "[2", K.buf.focus_left_2)
ms({ "n", "v" }, "[3", K.buf.focus_left_3)
ms({ "n", "v" }, "[4", K.buf.focus_left_4)
ms({ "n", "v" }, "[5", K.buf.focus_left_5)
ms({ "n", "v" }, "[6", K.buf.focus_left_6)
ms({ "n", "v" }, "[7", K.buf.focus_left_7)
ms({ "n", "v" }, "[8", K.buf.focus_left_8)
ms({ "n", "v" }, "[9", K.buf.focus_left_9)
ms({ "n", "v" }, "]b", K.buf.focus_right)
ms({ "n", "v" }, "]1", K.buf.focus_right_1)
ms({ "n", "v" }, "]2", K.buf.focus_right_2)
ms({ "n", "v" }, "]3", K.buf.focus_right_3)
ms({ "n", "v" }, "]4", K.buf.focus_right_4)
ms({ "n", "v" }, "]5", K.buf.focus_right_5)
ms({ "n", "v" }, "]6", K.buf.focus_right_6)
ms({ "n", "v" }, "]7", K.buf.focus_right_7)
ms({ "n", "v" }, "]8", K.buf.focus_right_8)
ms({ "n", "v" }, "]9", K.buf.focus_right_9)
ms({ "n", "v" }, "<leader>01", K.buf.focus_01)
ms({ "n", "v" }, "<leader>02", K.buf.focus_02)
ms({ "n", "v" }, "<leader>03", K.buf.focus_03)
ms({ "n", "v" }, "<leader>04", K.buf.focus_04)
ms({ "n", "v" }, "<leader>05", K.buf.focus_05)
ms({ "n", "v" }, "<leader>06", K.buf.focus_06)
ms({ "n", "v" }, "<leader>07", K.buf.focus_07)
ms({ "n", "v" }, "<leader>08", K.buf.focus_08)
ms({ "n", "v" }, "<leader>09", K.buf.focus_09)
ms({ "n", "v" }, "<leader>b01", K.buf.focus_01)
ms({ "n", "v" }, "<leader>b02", K.buf.focus_02)
ms({ "n", "v" }, "<leader>b03", K.buf.focus_03)
ms({ "n", "v" }, "<leader>b04", K.buf.focus_04)
ms({ "n", "v" }, "<leader>b05", K.buf.focus_05)
ms({ "n", "v" }, "<leader>b06", K.buf.focus_06)
ms({ "n", "v" }, "<leader>b07", K.buf.focus_07)
ms({ "n", "v" }, "<leader>b08", K.buf.focus_08)
ms({ "n", "v" }, "<leader>b09", K.buf.focus_09)
ms({ "n", "v" }, "<leader>b10", K.buf.focus_10)
ms({ "n", "v" }, "<leader>b11", K.buf.focus_11)
ms({ "n", "v" }, "<leader>b12", K.buf.focus_12)
ms({ "n", "v" }, "<leader>b13", K.buf.focus_13)
ms({ "n", "v" }, "<leader>b14", K.buf.focus_14)
ms({ "n", "v" }, "<leader>b15", K.buf.focus_15)
ms({ "n", "v" }, "<leader>b16", K.buf.focus_16)
ms({ "n", "v" }, "<leader>b17", K.buf.focus_17)
ms({ "n", "v" }, "<leader>b18", K.buf.focus_18)
ms({ "n", "v" }, "<leader>b19", K.buf.focus_19)
ms({ "n", "v" }, "<leader>b20", K.buf.focus_10)
ms({ "n", "v" }, "<leader>b21", K.buf.focus_21)
ms({ "n", "v" }, "<leader>b22", K.buf.focus_22)
ms({ "n", "v" }, "<leader>b23", K.buf.focus_23)
ms({ "n", "v" }, "<leader>b24", K.buf.focus_24)
ms({ "n", "v" }, "<leader>b25", K.buf.focus_25)
ms({ "n", "v" }, "<leader>b26", K.buf.focus_26)
ms({ "n", "v" }, "<leader>b27", K.buf.focus_27)
ms({ "n", "v" }, "<leader>b28", K.buf.focus_28)
ms({ "n", "v" }, "<leader>b29", K.buf.focus_29)
ms({ "n", "v" }, "<leader>b30", K.buf.focus_30)
ms({ "n", "v" }, "<leader>b31", K.buf.focus_31)
ms({ "n", "v" }, "<leader>b32", K.buf.focus_32)
ms({ "n", "v" }, "<leader>b33", K.buf.focus_33)
ms({ "n", "v" }, "<leader>b34", K.buf.focus_34)
ms({ "n", "v" }, "<leader>b35", K.buf.focus_35)
ms({ "n", "v" }, "<leader>b36", K.buf.focus_36)
ms({ "n", "v" }, "<leader>b37", K.buf.focus_37)
ms({ "n", "v" }, "<leader>b38", K.buf.focus_38)
ms({ "n", "v" }, "<leader>b39", K.buf.focus_39)
ms({ "n", "v" }, "<leader>b40", K.buf.focus_40)
ms({ "n", "v" }, "<leader>b41", K.buf.focus_41)
ms({ "n", "v" }, "<leader>b42", K.buf.focus_42)
ms({ "n", "v" }, "<leader>b43", K.buf.focus_43)
ms({ "n", "v" }, "<leader>b44", K.buf.focus_44)
ms({ "n", "v" }, "<leader>b45", K.buf.focus_45)
ms({ "n", "v" }, "<leader>b46", K.buf.focus_46)
ms({ "n", "v" }, "<leader>b47", K.buf.focus_47)
ms({ "n", "v" }, "<leader>b48", K.buf.focus_48)
ms({ "n", "v" }, "<leader>b49", K.buf.focus_49)
ms({ "n", "v" }, "<leader>[", K.buf.focus_left)
ms({ "n", "v" }, "<leader>]", K.buf.focus_right)
ms({ "n", "v" }, "<leader>{", K.buf.swap_left)
ms({ "n", "v" }, "<leader>}", K.buf.swap_right)
ms({ "n", "v" }, "<leader>b[", K.buf.focus_left)
ms({ "n", "v" }, "<leader>b]", K.buf.focus_right)
ms({ "n", "v" }, "<leader>b{", K.buf.swap_left)
ms({ "n", "v" }, "<leader>b}", K.buf.swap_right)
ms({ "n", "v" }, "<leader>ba", K.find.bufs)
ms({ "n", "v" }, "<leader>bb", K.find.bufs_file)
ms({ "n", "v" }, "<leader>bd", K.buf.close)
ms({ "n", "v" }, "<leader>bh", K.buf.close_to_leftest)
ms({ "n", "v" }, "<leader>bl", K.buf.close_to_rightest)
ms({ "n", "v" }, "<leader>bn", K.buf.new)
ms({ "n", "v" }, "<leader>bo", K.buf.close_others)
ms({ "n", "v" }, "<leader>bp", K.buf.pin)
ms({ "n", "v" }, "<leader>bt", K.find.bufs_term)
--------------------------------------------------------------------------------------------#[b]uf--

--#[c]lipboard------------------------------------------------------------------------------------
ms({ "i", "n", "v" }, "<leader>cp", K.clipboard.paste)
------------------------------------------------------------------------------------#[c]lipboard--

--#[c]ode-------------------------------------------------------------------------------------------
ms({ "i", "n", "v" }, "<F5>", K.code.run)
ms({ "i", "n", "v" }, "<F17>", K.code.run_force) -- F5 mapped to F17
ms({ "n" }, "<leader>cs", K.code.swap_conditional_branches)
-------------------------------------------------------------------------------------------#[c]ode--

--#[c]opy-------------------------------------------------------------------------------------------
ms({ "i", "n", "v" }, { "<C-a>C", "<D-C>", "<M-C>" }, K.copy.filepath)
-----------------------------------------------------------------------------------------#[c]opy----

--#[i]nspect----------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>ib", K.inspect.inspect_buf)
ms({ "n", "v" }, "<leader>iI", K.inspect.inspect_tree)
ms({ "n", "v" }, "<leader>ii", K.inspect.inspect_pos)
ms({ "n", "v" }, "<leader>is", K.inspect.inspect_state)
ms({ "n", "v" }, "<leader>iS", K.inspect.inspect_state_full)
ms({ "n", "v" }, "<leader>it", K.inspect.inspect_tab)
ms({ "n", "v" }, "<leader>iw", K.inspect.inspect_window)
----------------------------------------------------------------------------------------#[i]nspect--

--#[e]xplorer---------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>ee", K.explorer.last)
ms({ "n", "v" }, "<leader>eF", K.explorer.fs_workspace)
ms({ "n", "v" }, "<leader>ef", K.explorer.fs_cwd)
ms({ "n", "v" }, "<leader>eG", K.explorer.git_workspace)
ms({ "n", "v" }, "<leader>eg", K.explorer.git_cwd)
ms({ "n", "v" }, "<leader>er", K.explorer.fs_reveal)
ms({ "n", "v" }, "<leader>et", K.explorer.toggle)
---------------------------------------------------------------------------------------#[e]xplorer--

--#[f]ind-------------------------------------------------------------------------------------------
if std.path.is_repo_git() then
  ms({ "n", "v" }, "<leader><leader>", K.find.files)
else
  ms({ "n", "v" }, "<leader><leader>", K.find.explorer)
end
ms({ "n", "v" }, "<leader>fb", K.find.bufs)
ms({ "n", "v" }, "<leader>fc", K.find.files_cwd)
ms({ "n", "v" }, "<leader>fe", K.find.explorer)
ms({ "n", "v" }, "<leader>ff", K.find.files)
ms({ "n", "v" }, "<leader>fg", K.find.git_not_committed)
ms({ "n", "v" }, "<leader>fh", K.find.highlights)
ms({ "n", "v" }, "<leader>fn", K.find.notifications)
ms({ "n", "v" }, "<leader>fp", K.find.pinned_files)
ms({ "n", "v" }, "<leader>ft", K.find.bufs_term)
ms({ "n", "v" }, "<leader>fv", K.find.vim_options)
ms({ "n", "v" }, "<leader>fw", K.find.files_workspace)
-------------------------------------------------------------------------------------------#[f]ind--

--#[g]it--------------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>gB", K.git.browse)
ms({ "n", "v" }, "<leader>gf", K.git.history_file)
ms({ "n", "v" }, "<leader>gG", K.git.history)
ms({ "n", "v" }, "<leader>gg", K.git.diffview)
--------------------------------------------------------------------------------------------#[g]it--

--#[]lint-------------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>sa", K.lint.spellcheck_register)
-------------------------------------------------------------------------------------------#[]lint--

--#[p]rofile----------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>pp", K.profile.start)
ms({ "n", "v" }, "<leader>ps", K.profile.stop)
----------------------------------------------------------------------------------------#[p]rofile--

--#[q]uit-------------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>qL", K.session.restore_autosaved)
ms({ "n", "v" }, "<leader>ql", K.session.restore)
ms({ "n", "v" }, "<leader>qs", K.session.save)
-------------------------------------------------------------------------------------------#[q]uit--

--#[r]efresh----------------------------------------------------------------------------------------
ms({ "i", "n", "v" }, { "<C-a>r", "<D-r>", "<M-r>" }, K.refresh.all)
---------------------------------------------------------------------------------------#[r]efresh---

--#[r]eplace----------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>rr", K.replace.files)
ms({ "n", "v" }, "<leader>rb", K.replace.files_in_buffer)
ms({ "n", "v" }, "<leader>rd", K.replace.files_in_directory)
ms({ "n", "v" }, "<leader>rc", K.replace.files_in_cwd)
ms({ "n", "v" }, "<leader>rw", K.replace.files_in_workspace)
---------------------------------------------------------------------------------------#[r]eplace---

--#[s]earch-----------------------------------------------------------------------------------------
ms({ "i", "n", "v" }, { "<C-a>f", "<D-f>", "<M-f>" }, K.search.files_in_buffer)
ms({ "n", "v" }, "<leader>ss", K.search.files)
ms({ "n", "v" }, "<leader>sb", K.search.files_in_buffer)
ms({ "n", "v" }, "<leader>sc", K.search.files_in_cwd)
ms({ "n", "v" }, "<leader>sd", K.search.files_in_directory)
ms({ "n", "v" }, "<leader>sw", K.search.files_in_workspace)
-----------------------------------------------------------------------------------------#[s]earch--

--#[t]ab--------------------------------------------------------------------------------------------
ms({ "n", "v" }, "[t", K.tab.focus_left)
ms({ "n", "v" }, "]t", K.tab.focus_right)
ms({ "n", "v" }, "<leader>,", K.tab.focus_left)
ms({ "n", "v" }, "<leader>.", K.tab.focus_right)
ms({ "n", "v" }, "<leader>t[", K.tab.focus_left)
ms({ "n", "v" }, "<leader>t]", K.tab.focus_right)
ms({ "n", "v" }, "<leader>t1", K.tab.focus_1)
ms({ "n", "v" }, "<leader>t2", K.tab.focus_2)
ms({ "n", "v" }, "<leader>t3", K.tab.focus_3)
ms({ "n", "v" }, "<leader>t4", K.tab.focus_4)
ms({ "n", "v" }, "<leader>t5", K.tab.focus_5)
ms({ "n", "v" }, "<leader>t6", K.tab.focus_6)
ms({ "n", "v" }, "<leader>t7", K.tab.focus_7)
ms({ "n", "v" }, "<leader>t8", K.tab.focus_8)
ms({ "n", "v" }, "<leader>t9", K.tab.focus_9)
ms({ "n", "v" }, "<leader>t0", K.tab.focus_10)
ms({ "n", "v" }, "<leader>td", K.tab.close)
ms({ "n", "v" }, "<leader>th", K.tab.close_to_leftest)
ms({ "n", "v" }, "<leader>tl", K.tab.close_to_rightest)
ms({ "n", "v" }, "<leader>to", K.tab.close_others)
ms({ "n", "v" }, "<leader>tN", K.tab.new)
ms({ "n", "v" }, "<leader>tn", K.tab.new_with_buf)
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]erminal---------------------------------------------------------------------------------------
ms({ "i", "n", "t", "v" }, { "<C-a>g", "<D-g>", "<M-g>" }, K.term.lazygit_cwd)
ms({ "i", "n", "t", "v" }, { "<C-a>t", "<D-t>", "<M-t>" }, K.term.toggle_cwd)
ms({ "i", "n", "t", "v" }, { "<C-a>y", "<D-y>", "<M-y>" }, K.term.yazi_reveal)
---------------------------------------------------------------------------------------#[t]erminal--

--#[t]oggle-----------------------------------------------------------------------------------------
ms({ "i", "n", "v" }, { "<C-a>T", "<D-T>", "<M-T>" }, K.toggle.theme_variant)
ms({ "n", "v" }, "<leader>tM", K.toggle.markdown)
ms({ "n", "v" }, "<leader>tR", K.toggle.relativenumber)
ms({ "n", "v" }, "<leader>tS", K.toggle.theme)
ms({ "n", "v" }, "<leader>tT", K.toggle.transparency)
ms({ "n", "v" }, "<leader>tt", K.toggle.list)
ms({ "n", "v" }, "<leader>tU", K.toggle.username)
ms({ "n", "v" }, "<leader>z", K.toggle.maximize)
-----------------------------------------------------------------------------------------#[t]oggle--

--#[u]x---------------------------------------------------------------------------------------------
ms({ "n", "v" }, "<leader>un", K.ux.dismiss_notifications)
---------------------------------------------------------------------------------------------#[u]x--

--#[w]in--------------------------------------------------------------------------------------------
ms({ "i", "n", "v" }, { "<C-a><Left>", "<D-Left>", "<M-Left>" }, K.win.resize_vertical_minus)
ms({ "i", "n", "v" }, { "<C-a><Down>", "<D-Down>", "<M-Down>" }, K.win.resize_horizontal_minus)
ms({ "i", "n", "v" }, { "<C-a><Up>", "<D-Up>", "<M-Up>" }, K.win.resize_horizontal_plus)
ms({ "i", "n", "v" }, { "<C-a><Right>", "<D-Right>", "<M-Right>" }, K.win.resize_vertical_plus)
ms({ "i", "n", "v" }, { "<C-a>i", "<D-i>", "<M-i>" }, K.win.history_backward)
ms({ "i", "n", "v" }, { "<C-a>o", "<D-o>", "<M-o>" }, K.win.history_forward)
ms({ "i", "n", "t", "v" }, { "<C-a>h", "<D-h>", "<M-h>" }, K.win.focus_left)
ms({ "i", "n", "t", "v" }, { "<C-a>j", "<D-j>", "<M-j>" }, K.win.focus_bottom)
ms({ "i", "n", "t", "v" }, { "<C-a>k", "<D-k>", "<M-k>" }, K.win.focus_top)
ms({ "i", "n", "t", "v" }, { "<C-a>l", "<D-l>", "<M-l>" }, K.win.focus_right)
ms({ "n", "v" }, "<leader>wd", K.win.close)
ms({ "n", "v" }, "<leader>wh", K.win.history)
ms({ "n", "v" }, "<leader>wk", K.win.split_above)
ms({ "n", "v" }, "<leader>wl", K.win.split_right)
ms({ "n", "v" }, "<leader>wj", K.win.split_below)
ms({ "n", "v" }, "<leader>wo", K.win.close_others)
ms({ "n", "v" }, "<leader>wp", K.win.project)
ms({ "n", "v" }, "<leader>ws", K.win.swap)
ms({ "n", "v" }, "<leader>ww", K.win.focus)
ms({ "n", "v" }, "<leader>sj", K.win.scroll_down)
ms({ "n", "v" }, "<leader>sk", K.win.scroll_up)
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
ms({ "n", "v" }, "[d", K.diagnostic.goto_prev)
ms({ "n", "v" }, "]d", K.diagnostic.goto_next)
ms({ "n", "v" }, "[e", K.diagnostic.goto_prev_error)
ms({ "n", "v" }, "]e", K.diagnostic.goto_next_error)
ms({ "n", "v" }, "[q", K.diagnostic.goto_prev_quickfix)
ms({ "n", "v" }, "]q", K.diagnostic.goto_next_quickfix)
ms({ "n", "v" }, "[w", K.diagnostic.goto_prev_warn)
ms({ "n", "v" }, "]w", K.diagnostic.goto_next_warn)
ms({ "n", "v" }, "<leader>xl", K.diagnostic.line)
ms({ "n", "v" }, "<leader>xo", K.diagnostic.outline)
-----------------------------------------------------------------------------------#[x] diagnostic--
