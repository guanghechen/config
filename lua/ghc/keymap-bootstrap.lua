---@class ghc.keymap.actions
local A = {
  buffer = require("ghc.core.action.buffer"),
  context = require("ghc.core.action.context"),
  debug = require("ghc.core.action.debug"),
  enhance = require("ghc.core.action.enhance"),
  file = require("ghc.core.action.file"),
  run = require("ghc.core.action.run"),
  session = require("ghc.core.action.session"),
  tab = require("ghc.core.action.tab"),
  toggle = require("ghc.core.action.toggle"),
  window = require("ghc.core.action.window"),
}

---@param mode string | string[]
---@param key string
---@param action any
---@param desc string
---@param silent? boolean
local function mk(mode, key, action, desc, silent)
  vim.keymap.set(mode, key, action, { noremap = true, silent = silent ~= nil and silent or false, desc = desc })
end

--#enhance------------------------------------------------------------------------------------------
-- better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- better up/down
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "down" })
vim.keymap.set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "down" })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "up" })
vim.keymap.set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "up" })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "next Search Result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "next Search Result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "next Search Result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "prev Search Result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "prev Search Result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "prev Search Result" })

mk("n", "<esc>", "<cmd>noh<cr><esc>", "remove search highlights", true) -- Clear search with <esc>
mk("t", "<esc><esc>", "<C-\\><C-n>", "terminal: exit terminal mode", true) -- Exit terminal

-- better copy/paste
mk("v", "<C-b>c", '"+y', "copy to system clipboard")
mk("v", "<M-c>", '"+y', "copy to system clipboard")
mk("v", "<C-b>x", '"+x', "cut to system clipboard")
mk("v", "<M-x>", '"+x', "cut to system clipboard")
mk({ "i", "n", "v" }, "<C-b>a", "<esc>gg0vG$", "select all")
mk({ "i", "n", "v" }, "<M-a>", "<esc>gg0vG$", "select all")
mk({ "i", "n", "v" }, "<C-b>v", '<esc>"+p', "paste: from system clipboard")
mk({ "i", "n", "v" }, "<M-v>", '<esc>"+p', "paste: from system clipboard")
mk({ "i", "n", "v" }, "<C-C>", A.enhance.copy_current_buffer_filepath, "copy: current buffer filepath")
---------------------------------------------------------------------------------------#enhance-----

--#navigation---------------------------------------------------------------------------------------
----- tab -----
mk({ "n", "v" }, "<leader><", A.tab.goto_tab_left, "tab: goto left tab", true)
mk({ "n", "v" }, "<leader>>", A.tab.goto_tab_right, "tab: goto right tab", true)
mk({ "n", "v" }, "[t", A.tab.goto_tab_left, "tab: goto left tab", true)
mk({ "n", "v" }, "]t", A.tab.goto_tab_right, "tab: goto right tab", true)

----- window -----
mk({ "i", "n", "v" }, "<C-b>h", A.window.focus_window_left, "window: focus on the left window", true)
mk({ "i", "n", "v" }, "<C-b>j", A.window.focus_window_bottom, "window: focus on the bottom window", true)
mk({ "i", "n", "v" }, "<C-b>k", A.window.focus_window_top, "window: focus on the top window", true)
mk({ "i", "n", "v" }, "<C-b>l", A.window.focus_window_right, "window: focus on the right window", true)
mk({ "i", "n", "v" }, "<M-h>", A.window.focus_window_left, "window: focus on the left window", true)
mk({ "i", "n", "v" }, "<M-j>", A.window.focus_window_bottom, "window: focus on the bottom window", true)
mk({ "i", "n", "v" }, "<M-k>", A.window.focus_window_top, "window: focus on the top window", true)
mk({ "i", "n", "v" }, "<M-l>", A.window.focus_window_right, "window: focus on the right window", true)
mk({ "i", "n", "v" }, "<C-b>i", A.window.back, "window: back", true)
mk({ "i", "n", "v" }, "<C-b>o", A.window.forward, "window: forward", true)
mk({ "i", "n", "v" }, "<M-i>", A.window.back, "window: back", true)
mk({ "i", "n", "v" }, "<M-o>", A.window.forward, "window: forward", true)

----- buffer -----
mk({ "n", "v" }, "<leader>[", A.buffer.open_buffer_left, "buffer: open left buffer", true)
mk({ "n", "v" }, "<leader>]", A.buffer.open_buffer_right, "buffer: open right buffer", true)
mk({ "n", "v" }, "[b", A.buffer.open_buffer_left, "buffer: open left buffer", true)
mk({ "n", "v" }, "]b", A.buffer.open_buffer_right, "buffer: open right buffer", true)

----- jump list -----
mk({ "i", "n", "v" }, "<C-i>", "<C-o>", "jump back", true)
mk({ "i", "n", "v" }, "<C-o>", "<C-i>", "jump forward", true)
---------------------------------------------------------------------------------------#navigation--

--[#]buffer-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>b1", A.buffer.open_buffer_1, "buffer: open buffer 1", true)
mk({ "n", "v" }, "<leader>b2", A.buffer.open_buffer_2, "buffer: open buffer 2", true)
mk({ "n", "v" }, "<leader>b3", A.buffer.open_buffer_3, "buffer: open buffer 3", true)
mk({ "n", "v" }, "<leader>b4", A.buffer.open_buffer_4, "buffer: open buffer 4", true)
mk({ "n", "v" }, "<leader>b5", A.buffer.open_buffer_5, "buffer: open buffer 5", true)
mk({ "n", "v" }, "<leader>b6", A.buffer.open_buffer_6, "buffer: open buffer 6", true)
mk({ "n", "v" }, "<leader>b7", A.buffer.open_buffer_7, "buffer: open buffer 7", true)
mk({ "n", "v" }, "<leader>b8", A.buffer.open_buffer_8, "buffer: open buffer 8", true)
mk({ "n", "v" }, "<leader>b9", A.buffer.open_buffer_9, "buffer: open buffer 9", true)
mk({ "n", "v" }, "<leader>b0", A.buffer.open_buffer_10, "buffer: open buffer 10", true)
mk({ "n", "v" }, "<leader>b[", A.buffer.open_buffer_left, "buffer: open left buffer", true)
mk({ "n", "v" }, "<leader>b]", A.buffer.open_buffer_right, "buffer: open right buffer", true)
mk({ "n", "v" }, "<leader>ba", A.buffer.close_buffer_all, "buffer: close all buffers", true)
mk({ "n", "v" }, "<leader>bd", A.buffer.close_buffer, "buffer: close current buffer", true)
mk({ "n", "v" }, "<leader>bh", A.buffer.close_buffer_to_leftest, "buffer: close buffers to the leftest", true)
mk({ "n", "v" }, "<leader>bl", A.buffer.close_buffer_to_rightest, "buffer: close buffers to the rightest", true)
mk({ "n", "v" }, "<leader>bn", A.buffer.new_buffer, "buffer: new buffer", true)
mk({ "n", "v" }, "<leader>bo", A.buffer.close_buffer_others, "buffer: close other buffers", true)
-----------------------------------------------------------------------------------------#[b]uffer--

----#[d]ebug-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>dC", A.debug.show_context_all, "debug: show context (all)", true)
mk({ "n", "v" }, "<leader>dc", A.debug.show_context, "debug: show context (persistentable)", true)
mk({ "n", "v" }, "<leader>dw", A.window.show_window_history, "debug: show window history", true)
-------------------------------------------------------------------------------------------#[d]ebug--

--#[f]ile-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>fn", A.file.new_file, "file: new file")
-------------------------------------------------------------------------------------------#[f]ile--

--#[q]uit/session/context--------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>qq", A.session.quit_all, "quit: quit all", true)
mk({ "n", "v" }, "<leader>qL", A.session.session_load_autosaved, "session: restore autosaved session", true)
mk({ "n", "v" }, "<leader>ql", A.session.session_load, "session: restore session", true)
mk({ "n", "v" }, "<leader>qo", A.context.edit_session, "context: restore session", true)
mk({ "n", "v" }, "<leader>qs", A.session.session_save, "session: save session", true)
mk({ "n", "v" }, "<leader>qc", A.session.session_clear, "session: clear session", true)
mk({ "n", "v" }, "<leader>qC", A.session.session_clear_all, "session: clear all sessions", true)
--------------------------------------------------------------------------#[q]uit/session/context--

--#[r]un--------------------------------------------------------------------------------------------
mk({ "i", "n", "v" }, "<F5>", A.run.run, "run: run codes", true)
--------------------------------------------------------------------------------------------#[r]un--

--#[t]ab--------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>t1", A.tab.goto_tab_1, "tab: goto tab 1", true)
mk({ "n", "v" }, "<leader>t2", A.tab.goto_tab_2, "tab: goto tab 2", true)
mk({ "n", "v" }, "<leader>t3", A.tab.goto_tab_3, "tab: goto tab 3", true)
mk({ "n", "v" }, "<leader>t4", A.tab.goto_tab_4, "tab: goto tab 4", true)
mk({ "n", "v" }, "<leader>t5", A.tab.goto_tab_5, "tab: goto tab 5", true)
mk({ "n", "v" }, "<leader>t6", A.tab.goto_tab_6, "tab: goto tab 6", true)
mk({ "n", "v" }, "<leader>t7", A.tab.goto_tab_7, "tab: goto tab 7", true)
mk({ "n", "v" }, "<leader>t8", A.tab.goto_tab_8, "tab: goto tab 8", true)
mk({ "n", "v" }, "<leader>t9", A.tab.goto_tab_9, "tab: goto tab 9", true)
mk({ "n", "v" }, "<leader>t0", A.tab.goto_tab_10, "tab: goto tab 10", true)
mk({ "n", "v" }, "<leader>t[", A.tab.goto_tab_left, "tab: goto left tab", true)
mk({ "n", "v" }, "<leader>t]", A.tab.goto_tab_right, "tab: goto right tab", true)
mk({ "n", "v" }, "<leader>tN", A.tab.open_tab_new, "tab: new tab", true)
mk({ "n", "v" }, "<leader>tn", A.tab.open_tab_new_with_current_buf, "tab: new tab with current buf", true)
mk({ "n", "v" }, "<leader>td", A.tab.close_tab_current, "tab: close current", true)
mk({ "n", "v" }, "<leader>th", A.tab.close_tab_to_leftest, "tab: close tabs to the leftest", true)
mk({ "n", "v" }, "<leader>tl", A.tab.close_tab_to_rightest, "tab: close tabs to the rightest", true)
mk({ "n", "v" }, "<leader>to", A.tab.close_tab_others, "tab: close other tabs", true)
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]oggle-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>tfc", A.toggle.flight_copilot, "toggle: copilot")
mk({ "n", "v" }, "<leader>tul", A.toggle.relative_line_number, "toggle: relative line number")
mk({ "n", "v" }, "<leader>tuT", A.toggle.transparency, "toggle: transparency")
mk({ "n", "v" }, "<leader>tut", A.toggle.theme, "toggle: theme")
mk({ "n", "v" }, "<leader>tuw", A.toggle.wrap, "toggle: wrap")
-----------------------------------------------------------------------------------------#[t]oggle--

--#[w]indow-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>wW", A.window.find_history_all, "window: find history", true)
mk({ "n", "v" }, "<leader>ww", A.window.find_history_unique, "window: find history (unique)", true)
mk({ "n", "v" }, "<leader>wf", A.window.focus_window_with_picker, "window: focus window (with picker)", true)
mk({ "n", "v" }, "<leader>ws", A.window.swap_window_with_picker, "window: swap window (with picker)", true)
mk({ "n", "v" }, "<leader>wp", A.window.project_window_with_picker, "window: project window (with picker)", true)
mk({ "n", "v" }, "<leader>wj", A.window.split_window_horizontal, "window: split window horizontally", true)
mk({ "n", "v" }, "<leader>wl", A.window.split_window_vertical, "window: split window vertically", true)
mk({ "n", "v" }, "<leader>wH", A.window.resize_window_vertical_minus, "window: resize -(v:count) vertically.", true)
mk({ "n", "v" }, "<leader>wJ", A.window.resize_window_horizontal_minus, "window: resize -(v:count) horizontally.", true)
mk({ "n", "v" }, "<leader>wK", A.window.resize_window_horizontal_plus, "window: resize +(v:count) horizontally.", true)
mk({ "n", "v" }, "<leader>wL", A.window.resize_window_vertical_plus, "window: resize +(v:count) vertically.", true)
mk({ "n", "v" }, "<leader>wd", A.window.close_window_current, "window: close current window", true)
mk({ "n", "v" }, "<leader>wo", A.window.close_window_others, "window: close others", true)
-----------------------------------------------------------------------------------------#[w]indow--
