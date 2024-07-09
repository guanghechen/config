---@param mode string | string[]
---@param key string
---@param action any
---@param desc string
---@param silent? boolean
local function mk(mode, key, action, desc, silent)
  vim.keymap.set(mode, key, action, { noremap = true, silent = silent ~= nil and silent or false, desc = desc })
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

mk("n", "<esc>", "<cmd>noh<cr><esc>", "remove search highlights", true) -- Clear search with <esc>
mk("t", "<esc><esc>", "<C-\\><C-n>", "terminal: exit terminal mode", true) -- Exit terminal

---! quick shortcut
mk({ "i", "n", "v" }, "<C-b>T", ghc.command.toggle.theme, "toggle: theme")
mk({ "i", "n", "v" }, "<M-T>", ghc.command.toggle.theme, "toggle: theme")

---! better copy/paste
mk("v", "<C-b>c", '"+y', "copy to system clipboard")
mk("v", "<M-c>", '"+y', "copy to system clipboard")
mk("v", "<C-b>x", '"+x', "cut to system clipboard")
mk("v", "<M-x>", '"+x', "cut to system clipboard")
mk({ "i", "n", "v" }, "<C-b>a", "<esc>gg0vG$", "select all")
mk({ "i", "n", "v" }, "<M-a>", "<esc>gg0vG$", "select all")
mk({ "i", "n", "v" }, "<C-b>v", '<esc>"+p', "paste: from system clipboard")
mk({ "i", "n", "v" }, "<M-v>", '<esc>"+p', "paste: from system clipboard")
mk({ "i", "n", "v" }, "<C-C>", ghc.command.copy.current_buffer_filepath, "copy: current buffer filepath")
---------------------------------------------------------------------------------------#enhance-----

--#navigation---------------------------------------------------------------------------------------
----- tab -----
mk({ "n", "v" }, "<leader><", fml.api.tab.focus_left, "tab: focus left", true)
mk({ "n", "v" }, "<leader>>", fml.api.tab.focus_right, "tab: focus right", true)
mk({ "n", "v" }, "[t", fml.api.tab.focus_left, "tab: focus left", true)
mk({ "n", "v" }, "]t", fml.api.tab.focus_right, "tab: focus right", true)

----- window -----
mk({ "i", "n", "v" }, "<C-b>h", fml.api.win.focus_left, "window: focus left", true)
mk({ "i", "n", "v" }, "<C-b>j", fml.api.win.focus_bottom, "window: focus bottom", true)
mk({ "i", "n", "v" }, "<C-b>k", fml.api.win.focus_top, "window: focus top", true)
mk({ "i", "n", "v" }, "<C-b>l", fml.api.win.focus_right, "window: focus right", true)
mk({ "i", "n", "v" }, "<M-h>", fml.api.win.focus_left, "window: focus left", true)
mk({ "i", "n", "v" }, "<M-j>", fml.api.win.focus_bottom, "window: focus bottom", true)
mk({ "i", "n", "v" }, "<M-k>", fml.api.win.focus_top, "window: focus top", true)
mk({ "i", "n", "v" }, "<M-l>", fml.api.win.focus_right, "window: focus right", true)
mk({ "i", "n", "v" }, "<C-b>i", fml.api.win.back, "window: back", true)
mk({ "i", "n", "v" }, "<C-b>o", fml.api.win.forward, "window: forward", true)
mk({ "i", "n", "v" }, "<M-i>", fml.api.win.back, "window: back", true)
mk({ "i", "n", "v" }, "<M-o>", fml.api.win.forward, "window: forward", true)

----- buffer -----
mk({ "n", "v" }, "<leader>[", fml.api.buf.focus_left, "buffer: focus left", true)
mk({ "n", "v" }, "<leader>]", fml.api.buf.focus_right, "buffer: focus right", true)
mk({ "n", "v" }, "[b", fml.api.buf.focus_left, "buffer: focus left", true)
mk({ "n", "v" }, "]b", fml.api.buf.focus_right, "buffer: focus right", true)

----- jump list -----
mk({ "i", "n", "v" }, "<C-i>", "<C-o>", "jump back", true)
mk({ "i", "n", "v" }, "<C-o>", "<C-i>", "jump forward", true)
---------------------------------------------------------------------------------------#navigation--

--[#]buffer-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>b1", fml.api.buf.focus_1, "buffer: focus buffer 1", true)
mk({ "n", "v" }, "<leader>b2", fml.api.buf.focus_2, "buffer: focus buffer 2", true)
mk({ "n", "v" }, "<leader>b3", fml.api.buf.focus_3, "buffer: focus buffer 3", true)
mk({ "n", "v" }, "<leader>b4", fml.api.buf.focus_4, "buffer: focus buffer 4", true)
mk({ "n", "v" }, "<leader>b5", fml.api.buf.focus_5, "buffer: focus buffer 5", true)
mk({ "n", "v" }, "<leader>b6", fml.api.buf.focus_6, "buffer: focus buffer 6", true)
mk({ "n", "v" }, "<leader>b7", fml.api.buf.focus_7, "buffer: focus buffer 7", true)
mk({ "n", "v" }, "<leader>b8", fml.api.buf.focus_8, "buffer: focus buffer 8", true)
mk({ "n", "v" }, "<leader>b9", fml.api.buf.focus_9, "buffer: focus buffer 9", true)
mk({ "n", "v" }, "<leader>b0", fml.api.buf.focus_10, "buffer: focus buffer 10", true)
mk({ "n", "v" }, "<leader>b[", fml.api.buf.focus_left, "buffer: focus left", true)
mk({ "n", "v" }, "<leader>b]", fml.api.buf.focus_right, "buffer: focus right", true)
mk({ "n", "v" }, "<leader>ba", fml.api.buf.close_all, "buffer: close all", true)
mk({ "n", "v" }, "<leader>bd", fml.api.buf.close_current, "buffer: close current", true)
mk({ "n", "v" }, "<leader>bh", fml.api.buf.close_to_leftest, "buffer: close to the leftest", true)
mk({ "n", "v" }, "<leader>bl", fml.api.buf.close_to_rightest, "buffer: close to the rightest", true)
mk({ "n", "v" }, "<leader>bn", fml.api.buf.create, "buffer: new", true)
mk({ "n", "v" }, "<leader>bo", fml.api.buf.close_others, "buffer: close others", true)
-----------------------------------------------------------------------------------------#[b]uffer--

----#[d]ebug-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>dC", ghc.command.debug.show_context_all, "debug: show context (all)", true)
mk({ "n", "v" }, "<leader>dc", ghc.command.debug.show_context, "debug: show context (persistentable)", true)
mk({ "n", "v" }, "<leader>dd", ghc.command.debug.inspect, "debug: inspect", true)
mk({ "n", "v" }, "<leader>ds", ghc.command.debug.show_state, "debug: show state", true)
mk({ "n", "v" }, "<leader>dw", fml.api.win.show_history, "debug: show window history", true)
-------------------------------------------------------------------------------------------#[d]ebug--

--#[q]uit/session/context--------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>qq", ghc.command.session.quit_all, "quit: quit all", true)
mk({ "n", "v" }, "<leader>qL", ghc.command.session.load_autosaved, "session: restore session (autosaved)", true)
mk({ "n", "v" }, "<leader>ql", ghc.command.session.load, "session: restore session", true)
mk({ "n", "v" }, "<leader>qo", ghc.command.context.edit_session, "context: edit session", true)
mk({ "n", "v" }, "<leader>qs", ghc.command.session.save, "session: save session", true)
mk({ "n", "v" }, "<leader>qc", ghc.command.session.clear_current, "session: clear", true)
mk({ "n", "v" }, "<leader>qC", ghc.command.session.clear_all, "session: clear all", true)
--------------------------------------------------------------------------#[q]uit/session/context--

--#[r]un--------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<F5>", ghc.command.run.run, "run: run codes", true)
--------------------------------------------------------------------------------------------#[r]un--

--#[t]ab--------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>t1", fml.api.tab.focus_1, "tab: focus tab 1", true)
mk({ "n", "v" }, "<leader>t2", fml.api.tab.focus_2, "tab: focus tab 2", true)
mk({ "n", "v" }, "<leader>t3", fml.api.tab.focus_3, "tab: focus tab 3", true)
mk({ "n", "v" }, "<leader>t4", fml.api.tab.focus_4, "tab: focus tab 4", true)
mk({ "n", "v" }, "<leader>t5", fml.api.tab.focus_5, "tab: focus tab 5", true)
mk({ "n", "v" }, "<leader>t6", fml.api.tab.focus_6, "tab: focus tab 6", true)
mk({ "n", "v" }, "<leader>t7", fml.api.tab.focus_7, "tab: focus tab 7", true)
mk({ "n", "v" }, "<leader>t8", fml.api.tab.focus_8, "tab: focus tab 8", true)
mk({ "n", "v" }, "<leader>t9", fml.api.tab.focus_9, "tab: focus tab 9", true)
mk({ "n", "v" }, "<leader>t0", fml.api.tab.focus_10, "tab: focus tab 10", true)
mk({ "n", "v" }, "<leader>t[", fml.api.tab.focus_left, "tab: focus the left tab", true)
mk({ "n", "v" }, "<leader>t]", fml.api.tab.focus_right, "tab: focus the right tab", true)
mk({ "n", "v" }, "<leader>tN", fml.api.tab.create, "tab: new tab", true)
mk({ "n", "v" }, "<leader>tn", fml.api.tab.create_with_buf, "tab: new tab with current buf", true)
mk({ "n", "v" }, "<leader>td", fml.api.tab.close_current, "tab: close", true)
mk({ "n", "v" }, "<leader>th", fml.api.tab.close_to_leftest, "tab: close tabs to the leftest", true)
mk({ "n", "v" }, "<leader>tl", fml.api.tab.close_to_rightest, "tab: close tabs to the rightest", true)
mk({ "n", "v" }, "<leader>to", fml.api.tab.close_others, "tab: close other tabs", true)
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]oggle-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>tfc", ghc.command.toggle.flight_copilot, "toggle: copilot")
mk({ "n", "v" }, "<leader>tul", ghc.command.toggle.relative_line_number, "toggle: relative line number")
mk({ "n", "v" }, "<leader>tuT", ghc.command.toggle.transparency, "toggle: transparency")
mk({ "n", "v" }, "<leader>tut", ghc.command.toggle.theme, "toggle: theme")
mk({ "n", "v" }, "<leader>tuw", ghc.command.toggle.wrap, "toggle: wrap")
-----------------------------------------------------------------------------------------#[t]oggle--

--#[w]indow-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>wW", fml.api.win.find_history_all, "window: find history", true)
mk({ "n", "v" }, "<leader>ww", fml.api.win.find_history_unique, "window: find history (unique)", true)
mk({ "n", "v" }, "<leader>wf", fml.api.win.focus_with_picker, "window: focus (with picker)", true)
mk({ "n", "v" }, "<leader>ws", fml.api.win.swap_with_picker, "window: swap (with picker)", true)
mk({ "n", "v" }, "<leader>wp", fml.api.win.project_with_picker, "window: project (with picker)", true)
mk({ "n", "v" }, "<leader>wj", fml.api.win.split_horizontal, "window: split horizontally", true)
mk({ "n", "v" }, "<leader>wl", fml.api.win.split_vertical, "window: split vertically", true)
mk({ "n", "v" }, "<leader>wH", fml.api.win.resize_vertical_minus, "window: resize -(v:count) vertically.", true)
mk({ "n", "v" }, "<leader>wJ", fml.api.win.resize_horizontal_minus, "window: resize -(v:count) horizontally.", true)
mk({ "n", "v" }, "<leader>wK", fml.api.win.resize_horizontal_plus, "window: resize +(v:count) horizontally.", true)
mk({ "n", "v" }, "<leader>wL", fml.api.win.resize_vertical_plus, "window: resize +(v:count) vertically.", true)
mk({ "n", "v" }, "<leader>wd", fml.api.win.close_current, "window: close current window", true)
mk({ "n", "v" }, "<leader>wo", fml.api.win.close_others, "window: close others", true)
-----------------------------------------------------------------------------------------#[w]indow--
