---@param mode                          string | string[]
---@param key                           string
---@param action                        any
---@param desc                          string
---@param silent                        ?boolean
---@param nowait                        ?boolean
local function mk(mode, key, action, desc, silent, nowait)
  vim.keymap.set(mode, key, action, { noremap = true, silent = silent, nowait = nowait, desc = desc })
end

---@return nil
local function resume_or_find_files()
  if not eve.widgets.resume() then
    ghc.command.find_files.open()
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
vim.keymap.set("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "next Search Result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "next Search Result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "next Search Result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "prev Search Result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "prev Search Result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "prev Search Result" })

mk("n", "<esc>", "<cmd>noh<cr><esc>", "remove search highlights", true, true) -- Clear search with <esc>
mk("t", "<esc><esc>", "<C-\\><C-n>", "terminal: exit terminal mode", true, true) -- Exit terminal

---! quick shortcut
mk({ "i", "n", "v" }, "<C-a>T", ghc.command.toggle.theme, "toggle: theme")
mk({ "i", "n", "v" }, "<M-T>", ghc.command.toggle.theme, "toggle: theme")

---! better access lazygit
mk({ "i", "n", "t", "v" }, "<C-a>g", ghc.command.git.toggle_lazygit_cwd, "git: toggle lazygit (cwd)", true)
mk({ "i", "n", "t", "v" }, "<M-g>", ghc.command.git.toggle_lazygit_cwd, "git: toggle lazygit (cwd)", true)

---! better access terminal
mk({ "i", "n", "t", "v" }, "<C-a>t", ghc.command.term.toggle_cwd, "terminal: toggle (cwd)")
mk({ "i", "n", "t", "v" }, "<M-t>", ghc.command.term.toggle_cwd, "terminal: toggle (cwd)")

---! better copy/paste
mk("v", "<C-a>c", '"+y', "system: copy to clipboard")
mk("v", "<M-c>", '"+y', "system: copy to clipboard")
mk("v", "<C-a>x", '"+x', "system: cut to clipboard")
mk("v", "<M-x>", '"+x', "system: cut to clipboard")
mk({ "i", "n", "v" }, "<C-a>s", fml.api.buf.save, "system: save changes")
mk({ "i", "n", "v" }, "<M-s>", fml.api.buf.save, "system: save changes")
mk({ "i", "n", "v" }, "<C-a>a", "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "v" }, "<M-a>", "<esc>gg0vG$", "system: select all")
mk({ "i", "n", "v" }, "<C-a>v", '<esc>"+p', "system: paste from clipboard")
mk({ "i", "n", "v" }, "<M-v>", '<esc>"+p', "system: paste from clipboard")
mk({ "i", "n", "v" }, "<Esc><C-c>", ghc.command.copy.current_buffer_filepath, "copy: current buffer filepath")
---------------------------------------------------------------------------------------#enhance-----

--#navigation---------------------------------------------------------------------------------------
----- buffer -----
mk({ "n", "v" }, "<leader>[", fml.api.buf.focus_left, "buf: focus left", true, true)
mk({ "n", "v" }, "<leader>]", fml.api.buf.focus_right, "buf: focus right", true, true)
mk({ "n", "v" }, "<leader>{", fml.api.buf.swap_left, "buf: swap left", true, true)
mk({ "n", "v" }, "<leader>}", fml.api.buf.swap_right, "buf: swap right", true, true)
mk({ "n", "v" }, "[b", fml.api.buf.focus_left, "buf: focus left", true, true)
mk({ "n", "v" }, "]b", fml.api.buf.focus_right, "buf: focus right", true, true)

----- tab -----
mk({ "n", "v" }, "<leader>,", fml.api.tab.focus_left, "tab: focus left", true, true)
mk({ "n", "v" }, "<leader>.", fml.api.tab.focus_right, "tab: focus right", true, true)
mk({ "n", "v" }, "[t", fml.api.tab.focus_left, "tab: focus left", true, true)
mk({ "n", "v" }, "]t", fml.api.tab.focus_right, "tab: focus right", true, true)

----- window -----
mk({ "i", "n", "t", "v" }, "<C-a>h", fml.api.win.focus_left, "win: focus left", true, true)
mk({ "i", "n", "t", "v" }, "<C-a>j", fml.api.win.focus_bottom, "win: focus bottom", true, true)
mk({ "i", "n", "t", "v" }, "<C-a>k", fml.api.win.focus_top, "win: focus top", true, true)
mk({ "i", "n", "t", "v" }, "<C-a>l", fml.api.win.focus_right, "win: focus right", true, true)
mk({ "i", "n", "t", "v" }, "<M-h>", fml.api.win.focus_left, "win: focus left", true, true)
mk({ "i", "n", "t", "v" }, "<M-j>", fml.api.win.focus_bottom, "win: focus bottom", true, true)
mk({ "i", "n", "t", "v" }, "<M-k>", fml.api.win.focus_top, "win: focus top", true, true)
mk({ "i", "n", "t", "v" }, "<M-l>", fml.api.win.focus_right, "win: focus right", true, true)
mk({ "i", "n", "v" }, "<C-a><Left>", fml.api.win.resize_vertical_minus, "win: resize -(v:count) vertically.", true)
mk({ "i", "n", "v" }, "<C-a><Down>", fml.api.win.resize_horizontal_minus, "win: resize -(v:count) horizontally.", true)
mk({ "i", "n", "v" }, "<C-a><Up>", fml.api.win.resize_horizontal_plus, "win: resize +(v:count) horizontally.", true)
mk({ "i", "n", "v" }, "<C-a><Right>", fml.api.win.resize_vertical_plus, "win: resize +(v:count) vertically.", true)
mk({ "i", "n", "v" }, "<M-Left>", fml.api.win.resize_vertical_minus, "win: resize -(v:count) vertically.", true)
mk({ "i", "n", "v" }, "<M-Down>", fml.api.win.resize_horizontal_minus, "win: resize -(v:count) horizontally.", true)
mk({ "i", "n", "v" }, "<M-Up>", fml.api.win.resize_horizontal_plus, "win: resize +(v:count) horizontally.", true)
mk({ "i", "n", "v" }, "<M-Right>", fml.api.win.resize_vertical_plus, "win: resize +(v:count) vertically.", true)
mk({ "i", "n", "v" }, "<C-a>i", fml.api.win.backward, "win: back", true, true)
mk({ "i", "n", "v" }, "<C-a>o", fml.api.win.forward, "win: forward", true, true)
mk({ "i", "n", "v" }, "<M-i>", fml.api.win.backward, "win: back", true, true)
mk({ "i", "n", "v" }, "<M-o>", fml.api.win.forward, "win: forward", true, true)

----- jump list -----
mk({ "i", "n", "v" }, "<C-i>", "<C-o>", "jump back", true, true)
mk({ "i", "n", "v" }, "<C-o>", "<C-i>", "jump forward", true, true)
---------------------------------------------------------------------------------------#navigation--

--[#]buffer-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>b1", fml.api.buf.focus_1, "buf: focus buffer 1", true, true)
mk({ "n", "v" }, "<leader>b2", fml.api.buf.focus_2, "buf: focus buffer 2", true, true)
mk({ "n", "v" }, "<leader>b3", fml.api.buf.focus_3, "buf: focus buffer 3", true, true)
mk({ "n", "v" }, "<leader>b4", fml.api.buf.focus_4, "buf: focus buffer 4", true, true)
mk({ "n", "v" }, "<leader>b5", fml.api.buf.focus_5, "buf: focus buffer 5", true, true)
mk({ "n", "v" }, "<leader>b6", fml.api.buf.focus_6, "buf: focus buffer 6", true, true)
mk({ "n", "v" }, "<leader>b7", fml.api.buf.focus_7, "buf: focus buffer 7", true, true)
mk({ "n", "v" }, "<leader>b8", fml.api.buf.focus_8, "buf: focus buffer 8", true, true)
mk({ "n", "v" }, "<leader>b9", fml.api.buf.focus_9, "buf: focus buffer 9", true, true)
mk({ "n", "v" }, "<leader>b0", fml.api.buf.focus_10, "buf: focus buffer 10", true, true)
mk({ "n", "v" }, "<leader>b[", fml.api.buf.focus_left, "buf: focus left", true, true)
mk({ "n", "v" }, "<leader>b]", fml.api.buf.focus_right, "buf: focus right", true, true)
mk({ "n", "v" }, "<leader>bd", fml.api.buf.close_current, "buf: close current", true)
mk({ "n", "v" }, "<leader>bh", fml.api.buf.close_to_leftest, "buf: close to the leftest", true)
mk({ "n", "v" }, "<leader>bl", fml.api.buf.close_to_rightest, "buf: close to the rightest", true)
mk({ "n", "v" }, "<leader>bn", fml.api.buf.create, "buf: new", true)
mk({ "n", "v" }, "<leader>bo", fml.api.buf.close_others, "buf: close others", true)
mk({ "n", "v" }, "<leader>bp", fml.api.buf.toggle_pin_cur, "buf: toggle pin", true)
-----------------------------------------------------------------------------------------#[b]uffer--

----#[d]ebug-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>dC", ghc.command.debug.show_context_all, "debug: show context (all)", true)
mk({ "n", "v" }, "<leader>dc", ghc.command.debug.show_context, "debug: show context (persistentable)", true)
mk({ "n", "v" }, "<leader>dd", ghc.command.debug.inspect, "debug: inspect", true)
mk({ "n", "v" }, "<leader>dI", ghc.command.debug.show_inspect_tree, "debug: show inspect tree")
mk({ "n", "v" }, "<leader>di", ghc.command.debug.show_inspect_pos, "debug: show inspect pos")
mk({ "n", "v" }, "<leader>dse", ghc.command.debug.show_editor_state, "debug: show editor state", true)
mk({ "n", "v" }, "<leader>dsi", ghc.command.debug.show_input_state, "debug: show input state", true)
-------------------------------------------------------------------------------------------#[d]ebug--

--#[f]ile-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>fn", fml.api.buf.create, "file: new", true)
-------------------------------------------------------------------------------------------#[f]ile--

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader><leader>", ghc.command.find_files.open, "find: files")
mk({ "n", "v" }, "<leader>fe", ghc.command.file_explorer.open, "find: file explorer")
mk({ "n", "v" }, "<leader>ff", ghc.command.find_files.open, "find: files")
mk({ "n", "v" }, "<leader>fw", ghc.command.find_files.open_workspace, "find: files (workspace)")
mk({ "n", "v" }, "<leader>fc", ghc.command.find_files.open_cwd, "find: files (cwd)")
mk({ "n", "v" }, "<leader>fd", ghc.command.find_files.open_directory, "find: files (directory)")
mk({ "n", "v" }, "<leader>fb", ghc.command.find_buffers.focus, "find: buffers")
mk({ "n", "v" }, "<leader>fg", ghc.command.find_git.list_uncommited_git_files, "find: git files (Not committed)")
mk({ "n", "v" }, "<leader>fh", ghc.command.find_highlights.toggle, "find: highlights")
mk({ "n", "v" }, "<leader>fv", ghc.command.find_vim_options.toggle, "find: vim options")
-------------------------------------------------------------------------------------------#[f]ind--

--#[g]it--------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>gf", ghc.command.git.open_diffview_filehistory, "git: open file history", true)
mk({ "n", "v" }, "<leader>gg", ghc.command.git.open_diffview, "git: open diff view", true)
-------------------------------------------------------------------------------------------#[g]it---

--#[q]uit/session/context--------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>qq", ghc.command.session.quit_all, "quit: quit all", true)
mk({ "n", "v" }, "<leader>qL", ghc.command.session.load_autosaved, "session: restore session (autosaved)", true)
mk({ "n", "v" }, "<leader>ql", ghc.command.session.load, "session: restore session", true)
mk({ "n", "v" }, "<leader>qo", ghc.command.context.edit_session, "context: edit session", true)
mk({ "n", "v" }, "<leader>qs", ghc.command.session.save, "session: save session", true)
mk({ "n", "v" }, "<leader>qc", ghc.command.session.clear_current, "session: clear", true)
mk({ "n", "v" }, "<leader>qC", ghc.command.session.clear_all, "session: clear all", true)
--------------------------------------------------------------------------#[q]uit/session/context---

--#[r]efresh----------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<C-a>r", ghc.command.refresh.refresh_all, "refresh: refresh all", true)
mk({ "i", "n", "v" }, "<M-r>", ghc.command.refresh.refresh_all, "refresh: refresh all", true)
---------------------------------------------------------------------------------------#[r]efresh---

--#[r]eplace----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>rr", ghc.command.search_files.open_replace, "replace: files")
mk({ "n", "v" }, "<leader>rw", ghc.command.search_files.open_replace_workspace, "replace: files (workspace)")
mk({ "n", "v" }, "<leader>rc", ghc.command.search_files.open_replace_cwd, "replace: files (cwd)")
mk({ "n", "v" }, "<leader>rd", ghc.command.search_files.open_replace_directory, "replace: files (directory)")
mk({ "n", "v" }, "<leader>rb", ghc.command.search_files.open_replace_buffer, "replace: files (buffer)")
---------------------------------------------------------------------------------------#[r]eplace---

--#[r]un--------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<F5>", ghc.command.run.run, "run: run codes", true)
--------------------------------------------------------------------------------------------#[r]un--

--#[s]earch-----------------------------------------------------------------------------------------
mk({ "n", "t", "v" }, "<leader>`", resume_or_find_files, "search: resume or find files")
mk({ "n", "v" }, "<leader>ss", ghc.command.search_files.open_search, "search: files")
mk({ "n", "v" }, "<leader>sw", ghc.command.search_files.open_search_workspace, "search: files (workspace)")
mk({ "n", "v" }, "<leader>sc", ghc.command.search_files.open_search_cwd, "search: files (cwd)")
mk({ "n", "v" }, "<leader>sd", ghc.command.search_files.open_search_directory, "search: files (directory)")
mk({ "n", "v" }, "<leader>sb", ghc.command.search_files.open_search_buffer, "search: files (buffer)")
mk({ "i", "n", "v" }, "<C-a>f", ghc.command.search_files.open_search_buffer, "search: files (buffer)")
mk({ "i", "n", "v" }, "<M-f>", ghc.command.search_files.open_search_buffer, "search: files (buffer)")
-----------------------------------------------------------------------------------------#[s]earch--

--#[s]croll-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>sj", ghc.command.scroll.down_half_window, "scroll: down half of window")
mk({ "n", "v" }, "<leader>sk", ghc.command.scroll.up_half_window, "scroll: up half of window")
-----------------------------------------------------------------------------------------#[s]croll--

--#[t]ab--------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>t1", fml.api.tab.focus_1, "tab: focus tab 1", true, true)
mk({ "n", "v" }, "<leader>t2", fml.api.tab.focus_2, "tab: focus tab 2", true, true)
mk({ "n", "v" }, "<leader>t3", fml.api.tab.focus_3, "tab: focus tab 3", true, true)
mk({ "n", "v" }, "<leader>t4", fml.api.tab.focus_4, "tab: focus tab 4", true, true)
mk({ "n", "v" }, "<leader>t5", fml.api.tab.focus_5, "tab: focus tab 5", true, true)
mk({ "n", "v" }, "<leader>t6", fml.api.tab.focus_6, "tab: focus tab 6", true, true)
mk({ "n", "v" }, "<leader>t7", fml.api.tab.focus_7, "tab: focus tab 7", true, true)
mk({ "n", "v" }, "<leader>t8", fml.api.tab.focus_8, "tab: focus tab 8", true, true)
mk({ "n", "v" }, "<leader>t9", fml.api.tab.focus_9, "tab: focus tab 9", true, true)
mk({ "n", "v" }, "<leader>t0", fml.api.tab.focus_10, "tab: focus tab 10", true, true)
mk({ "n", "v" }, "<leader>t[", fml.api.tab.focus_left, "tab: focus the left tab", true)
mk({ "n", "v" }, "<leader>t]", fml.api.tab.focus_right, "tab: focus the right tab", true)
mk({ "n", "v" }, "<leader>tN", fml.api.tab.create, "tab: new tab", true)
mk({ "n", "v" }, "<leader>tn", fml.api.tab.create_with_buf, "tab: new tab with current buf", true)
mk({ "n", "v" }, "<leader>td", fml.api.tab.close_current, "tab: close", true)
mk({ "n", "v" }, "<leader>th", fml.api.tab.close_to_leftest, "tab: close tabs to the leftest", true)
mk({ "n", "v" }, "<leader>tl", fml.api.tab.close_to_rightest, "tab: close tabs to the rightest", true)
mk({ "n", "v" }, "<leader>to", fml.api.tab.close_others, "tab: close other tabs", true)
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]merinal---------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>tT", ghc.command.term.toggle_workspace, "terminal: toggle (workspace)")
mk({ "n", "v" }, "<leader>tt", ghc.command.term.toggle_cwd, "terminal: toggle (cwd)")
---------------------------------------------------------------------------------------#[t]merinal--

--#[t]oggle-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>tfc", ghc.command.toggle.flight_copilot, "toggle: copilot")
mk({ "n", "v" }, "<leader>tfi", ghc.command.toggle.flag_case_sensitive, "toggle: case sensitive")
mk({ "n", "v" }, "<leader>tul", ghc.command.toggle.relativenumber, "toggle: relative line number")
mk({ "n", "v" }, "<leader>tuT", ghc.command.toggle.transparency, "toggle: transparency")
mk({ "n", "v" }, "<leader>tut", ghc.command.toggle.theme, "toggle: theme")
mk({ "n", "v" }, "<leader>tuw", ghc.command.toggle.wrap, "toggle: wrap")
-----------------------------------------------------------------------------------------#[t]oggle--

--#[w]indow-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>wh", ghc.command.find_win_history.focus, "win: history", true)
mk({ "n", "v" }, "<leader>wp", fml.api.win.project_with_picker, "win: project (with picker)", true)
mk({ "n", "v" }, "<leader>ws", fml.api.win.swap_with_picker, "win: swap (with picker)", true)
mk({ "n", "v" }, "<leader>ww", fml.api.win.focus_with_picker, "win: focus (with picker)", true)
mk({ "n", "v" }, "<leader>wj", fml.api.win.split_horizontal, "win: split horizontally", true)
mk({ "n", "v" }, "<leader>wl", fml.api.win.split_vertical, "win: split vertically", true)
mk({ "n", "v" }, "<leader>wd", fml.api.win.close_current, "win: close current window", true)
mk({ "n", "v" }, "<leader>wo", fml.api.win.close_others, "win: close others", true)
-----------------------------------------------------------------------------------------#[w]indow--
