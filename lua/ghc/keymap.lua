---@class ghc.keymap.actions
local A = {
  bookmark = require("ghc.core.action.bookmark"),
  buffer = require("ghc.core.action.buffer"),
  context = require("ghc.core.action.context"),
  debug = require("ghc.core.action.debug"),
  diagnostic = require("ghc.core.action.diagnostic"),
  enhance = require("ghc.core.action.enhance"),
  explorer = require("ghc.core.action.explorer"),
  find = require("ghc.core.action.find"),
  file = require("ghc.core.action.file"),
  git = require("ghc.core.action.git"),
  replace = require("ghc.core.action.replace"),
  search = require("ghc.core.action.search"),
  session = require("ghc.core.action.session"),
  tab = require("ghc.core.action.tab"),
  terminal = require("ghc.core.action.terminal"),
  toggle = require("ghc.core.action.toggle"),
  ui = require("ghc.core.action.ui"),
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
mk({ "i", "n", "v" }, "<C-b>a", "<esc>gg0vG$", "select all")
mk({ "i", "n", "v" }, "<M-a>", "<esc>gg0vG$", "select all")
mk({ "i", "n", "v" }, "<C-b>v", '<esc>"+p', "paste: from system clipboard")
mk({ "i", "n", "v" }, "<M-v>", '<esc>"+p', "paste: from system clipboard")
mk({ "i", "n", "v" }, "<C-C>", A.enhance.copy_current_buffer_filepath, "copy: current buffer filepath")

--- better window navigation
mk({ "i", "n", "v" }, "<C-b>h", A.window.focus_window_left, "window: focus on the left window", true)
mk({ "i", "n", "v" }, "<C-b>j", A.window.focus_window_bottom, "window: focus on the bottom window", true)
mk({ "i", "n", "v" }, "<C-b>k", A.window.focus_window_top, "window: focus on the top window", true)
mk({ "i", "n", "v" }, "<C-b>l", A.window.focus_window_right, "window: focus on the right window", true)
mk({ "i", "n", "v" }, "<M-h>", A.window.focus_window_left, "window: focus on the left window", true)
mk({ "i", "n", "v" }, "<M-j>", A.window.focus_window_bottom, "window: focus on the bottom window", true)
mk({ "i", "n", "v" }, "<M-k>", A.window.focus_window_top, "window: focus on the top window", true)
mk({ "i", "n", "v" }, "<M-l>", A.window.focus_window_right, "window: focus on the right window", true)

--- better access git from nvim
mk({ "i", "n", "t", "v" }, "<C-b>g", A.git.open_lazygit_cwd, "git: open lazygit (cwd)", true)
mk({ "i", "n", "t", "v" }, "<M-g>", A.git.open_lazygit_cwd, "git: open lazygit (cwd)", true)

--- better access terminal
mk({ "i", "n", "t", "v" }, "<C-b>t", A.terminal.open_terminal_cwd, "terminal: toggle terminal (cwd)")
mk({ "i", "n", "t", "v" }, "<M-t>", A.terminal.open_terminal_cwd, "terminal: toggle terminal (cwd)")
---------------------------------------------------------------------------------------#enhance-----

--#navigation---------------------------------------------------------------------------------------
----- tab -----
mk("n", "<leader><", A.tab.goto_tab_left, "tab: goto left tab", true)
mk("n", "<leader>>", A.tab.goto_tab_right, "tab: goto right tab", true)
mk("n", "[t", A.tab.goto_tab_left, "tab: goto left tab", true)
mk("n", "]t", A.tab.goto_tab_right, "tab: goto right tab", true)

----- buffer -----
mk("n", "<leader>1", A.buffer.open_buffer_1, "buffer: open buffer 1", true)
mk("n", "<leader>2", A.buffer.open_buffer_2, "buffer: open buffer 2", true)
mk("n", "<leader>3", A.buffer.open_buffer_3, "buffer: open buffer 3", true)
mk("n", "<leader>4", A.buffer.open_buffer_4, "buffer: open buffer 4", true)
mk("n", "<leader>5", A.buffer.open_buffer_5, "buffer: open buffer 5", true)
mk("n", "<leader>6", A.buffer.open_buffer_6, "buffer: open buffer 6", true)
mk("n", "<leader>7", A.buffer.open_buffer_7, "buffer: open buffer 7", true)
mk("n", "<leader>8", A.buffer.open_buffer_8, "buffer: open buffer 8", true)
mk("n", "<leader>9", A.buffer.open_buffer_9, "buffer: open buffer 9", true)
mk("n", "<leader>0", A.buffer.open_buffer_10, "buffer: open buffer 10", true)
mk("n", "<leader>[", A.buffer.open_buffer_left, "buffer: open left buffer", true)
mk("n", "<leader>]", A.buffer.open_buffer_right, "buffer: open right buffer", true)
mk("n", "[b", A.buffer.open_buffer_left, "buffer: open left buffer", true)
mk("n", "]b", A.buffer.open_buffer_right, "buffer: open right buffer", true)

----- diagnostic -----
mk("n", "[d", A.diagnostic.goto_prev_diagnostic, "diagnostic: goto prev diagnostic", true)
mk("n", "]d", A.diagnostic.goto_next_diagnostic, "diagnostic: goto next Diagnostic", true)
mk("n", "[e", A.diagnostic.goto_prev_error, "diagnostic: goto prev error", true)
mk("n", "]e", A.diagnostic.goto_next_error, "diagnostic: goto next error", true)
mk("n", "[q", A.diagnostic.toggle_previous_quickfix_item, "diagnostic: goto previous quickfix", true)
mk("n", "]q", A.diagnostic.toggle_next_quickfix_item, "diagnostic: goto next quickfix", true)
mk("n", "[w", A.diagnostic.goto_prev_warn, "diagnostic: goto prev warning", true)
mk("n", "]w", A.diagnostic.goto_next_warn, "diagnostic: goto next warning", true)
---------------------------------------------------------------------------------------#navigation--

--[#]buffer-----------------------------------------------------------------------------------------
mk("n", "<leader>b1", A.buffer.open_buffer_1, "buffer: open buffer 1", true)
mk("n", "<leader>b2", A.buffer.open_buffer_2, "buffer: open buffer 2", true)
mk("n", "<leader>b3", A.buffer.open_buffer_3, "buffer: open buffer 3", true)
mk("n", "<leader>b4", A.buffer.open_buffer_4, "buffer: open buffer 4", true)
mk("n", "<leader>b5", A.buffer.open_buffer_5, "buffer: open buffer 5", true)
mk("n", "<leader>b6", A.buffer.open_buffer_6, "buffer: open buffer 6", true)
mk("n", "<leader>b7", A.buffer.open_buffer_7, "buffer: open buffer 7", true)
mk("n", "<leader>b8", A.buffer.open_buffer_8, "buffer: open buffer 8", true)
mk("n", "<leader>b9", A.buffer.open_buffer_9, "buffer: open buffer 9", true)
mk("n", "<leader>b0", A.buffer.open_buffer_10, "buffer: open buffer 10", true)
mk("n", "<leader>b[", A.buffer.open_buffer_left, "buffer: open left buffer", true)
mk("n", "<leader>b]", A.buffer.open_buffer_right, "buffer: open right buffer", true)
mk("n", "<leader>ba", A.buffer.close_buffer_all, "buffer: close all buffers", true)
mk("n", "<leader>bb", A.buffer.open_buffer_last, "buffer: open last buffer", true)
mk("n", "<leader>bd", A.buffer.close_buffer, "buffer: close current buffer", true)
mk("n", "<leader>bh", A.buffer.close_buffer_to_leftest, "buffer: close buffers to the leftest", true)
mk("n", "<leader>bl", A.buffer.close_buffer_to_rightest, "buffer: close buffers to the rightest", true)
mk("n", "<leader>bn", A.buffer.new_buffer, "buffer: new buffer", true)
mk("n", "<leader>bo", A.buffer.close_buffer_others, "buffer: close other buffers", true)
-----------------------------------------------------------------------------------------#[b]uffer--

--#[c]ode-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------#[c]ode--

----#[d]ebug-----------------------------------------------------------------------------------------
mk("n", "<leader>dC", A.debug.show_context_all, "debug: show context (all)", true)
mk("n", "<leader>dc", A.debug.show_context, "debug: show context (persistentable)", true)
-------------------------------------------------------------------------------------------#[d]ebug--

--#[e]xplorer---------------------------------------------------------------------------------------
mk("n", "<leader>eB", A.explorer.toggle_explorer_buffer_workspace, "explorer: buffers (workspace)")
mk("n", "<leader>eb", A.explorer.toggle_explorer_buffer_cwd, "explorer: buffers (cwd)")
mk("n", "<leader>ee", A.explorer.toggle_explorer_last, "explorer: last")
mk("n", "<leader>eF", A.explorer.toggle_explorer_file_workspace, "explorer: files (workspace)")
mk("n", "<leader>ef", A.explorer.toggle_explorer_file_cwd, "explorer: files (cwd)")
mk("n", "<leader>eG", A.explorer.toggle_explorer_git_workspace, "explorer: git (workspace)")
mk("n", "<leader>eg", A.explorer.toggle_explorer_git_cwd, "explorer: git (cwd)")
mk("n", "<leader>er", A.explorer.reveal_file_explorer, "explorer: reveal file")
mk("n", "<leader>et", A.explorer.toggle_explorers, "explorer: toggle")
---------------------------------------------------------------------------------------#[e]xplorer--

--#[f]ile-------------------------------------------------------------------------------------------
mk("n", "<leader>fn", A.file.new_file, "file: new file")
-------------------------------------------------------------------------------------------#[f]ile--

--#[f]ind-------------------------------------------------------------------------------------------
mk("n", "<leader>fb", A.find.find_buffers, "find: buffers")
mk("n", "<leader>fE", A.find.find_explorer_workspace, "find: file explorer (from workspace)")
mk("n", "<leader>fe", A.find.find_explorer_current, "find: file explorer (from current directory)")
mk("n", "<leader>fF", A.find.find_file_force, "find: files (force)")
mk("n", "<leader>ff", A.find.find_file, "find: files")
mk("n", "<leader>fg", A.find.find_file_git, "find: files (git)")
mk("n", "<leader>fh", A.find.find_highlights, "find: highlights")
mk("n", "<leader>fm", A.find.find_bookmark_workspace, "find: bookmarks")
mk("n", "<leader>fq", A.find.find_quickfix_history, "find: quickfix history")
mk("n", "<leader>fr", A.find.find_recent, "find: recent")
mk("n", "<leader>fv", A.find.find_vim_options, "find: vim options")
mk("n", "<leader><leader>", A.find.find_recent, "find recent")
-------------------------------------------------------------------------------------------#[f]ind--

--#[g]it--------------------------------------------------------------------------------------------
mk("n", "<leader>gG", A.git.open_lazygit_workspace, "git: open lazygit (workspace)", true)
mk("n", "<leader>gg", A.git.open_lazygit_cwd, "git: open lazygit (cwd)", true)
mk("n", "<leader>gf", A.git.open_lazygit_file_history, "git: open lazygit file history", true)
-------------------------------------------------------------------------------------------#[g]it---

--#book[m]ark---------------------------------------------------------------------------------------
mk("n", "<leader>mm", A.bookmark.toggle_bookmark_on_current_line, "bookmark: toggle bookmark (current line)")
mk("n", "<leader>me", A.bookmark.edit_bookmark_annotation_on_current_line, "bookmark: edit bookmark (current line)")
mk("n", "<leader>mc", A.bookmark.clear_bookmark_on_current_buffer, "bookmark: clear bookmark (current buffer)")
mk("n", "<leader>m[", A.bookmark.goto_prev_bookmark_on_current_buffer, "bookmark: goto prev bookmark (current buffer)")
mk("n", "<leader>m]", A.bookmark.goto_next_bookmark_on_current_buffer, "bookmark: goto next bookmark (current buffer)")
mk("n", "<leader>ml", A.bookmark.open_bookmarks_into_quickfix, "bookmark: open bookmark list (quickfix)")
---------------------------------------------------------------------------------------#book[m]ark--

--#[q]uit/session/context--------------------------------------------------------------------------
mk("n", "<leader>qq", A.session.quit_all, "quit: quit all", true)
mk("n", "<leader>qL", A.session.session_load_autosaved, "session: restore autosaved session", true)
mk("n", "<leader>ql", A.session.session_load, "session: restore session", true)
mk("n", "<leader>qo", A.context.edit_session, "context: restore session", true)
mk("n", "<leader>qs", A.session.session_save, "session: save session", true)
mk("n", "<leader>qc", A.session.session_clear, "session: clear session", true)
mk("n", "<leader>qC", A.session.session_clear_all, "session: clear all sessions", true)
--------------------------------------------------------------------------#[q]uit/session/context--

--#[r]eplace----------------------------------------------------------------------------------------
mk("n", "<leader>rR", A.replace.replace_word_workspace, "replace: word (workspace)")
mk("n", "<leader>rr", A.replace.replace_word_current_file, "replace: word (current file)")
mk("v", "<leader>rti", A.replace.toggle_case_sensitive, "replace: toggle case sensitive")
----------------------------------------------------------------------------------------#[r]eplace--

--#[s]earch-----------------------------------------------------------------------------------------
-- mapkey("n", "<leader>sw", actions.search.grep_selected_text_workspace, "search: Grep word (workspace)")
-- mapkey("v", "<leader>sw", actions.search.grep_selected_text_workspace, "search: Grep word (workspace)")
-- mapkey("n", "<leader>sc", actions.search.grep_selected_text_cwd, "search: Grep word (cwd)")
-- mapkey("v", "<leader>sc", actions.search.grep_selected_text_cwd, "search: Grep word (cwd)")
-- mapkey("n", "<leader>sd", actions.search.grep_selected_text_directory, "search: Grep word (directory)")
-- mapkey("v", "<leader>sd", actions.search.grep_selected_text_directory, "search: Grep word (directory)")
-- mapkey("n", "<leader>sb", actions.search.grep_selected_text_buffer, "search: Grep word (file)")
-- mapkey("v", "<leader>sb", actions.search.grep_selected_text_buffer, "search: Grep word (file)")
mk("n", "<leader>ss", A.search.grep_selected_text, "search: grep word")
mk("v", "<leader>ss", A.search.grep_selected_text, "search: grep word")
-----------------------------------------------------------------------------------------#[s]earch--

--#[t]ab--------------------------------------------------------------------------------------------
mk("n", "<leader>t1", A.tab.goto_tab_1, "tab: goto tab 1", true)
mk("n", "<leader>t2", A.tab.goto_tab_2, "tab: goto tab 2", true)
mk("n", "<leader>t3", A.tab.goto_tab_3, "tab: goto tab 3", true)
mk("n", "<leader>t4", A.tab.goto_tab_4, "tab: goto tab 4", true)
mk("n", "<leader>t5", A.tab.goto_tab_5, "tab: goto tab 5", true)
mk("n", "<leader>t6", A.tab.goto_tab_6, "tab: goto tab 6", true)
mk("n", "<leader>t7", A.tab.goto_tab_7, "tab: goto tab 7", true)
mk("n", "<leader>t8", A.tab.goto_tab_8, "tab: goto tab 8", true)
mk("n", "<leader>t9", A.tab.goto_tab_9, "tab: goto tab 9", true)
mk("n", "<leader>t0", A.tab.goto_tab_10, "tab: goto tab 10", true)
mk("n", "<leader>t[", A.tab.goto_tab_left, "tab: goto left tab", true)
mk("n", "<leader>t]", A.tab.goto_tab_right, "tab: goto right tab", true)
mk("n", "<leader>tN", A.tab.open_tab_new, "tab: new tab", true)
mk("n", "<leader>tn", A.tab.open_tab_new_with_current_buf, "tab: new tab with current buf", true)
mk("n", "<leader>td", A.tab.close_tab_current, "tab: close current", true)
mk("n", "<leader>th", A.tab.close_tab_to_leftest, "tab: close tabs to the leftest", true)
mk("n", "<leader>tl", A.tab.close_tab_to_rightest, "tab: close tabs to the rightest", true)
mk("n", "<leader>to", A.tab.close_tab_others, "tab: close other tabs", true)
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]merinal---------------------------------------------------------------------------------------
mk("n", "<leader>tT", A.terminal.open_terminal_workspace, "terminal: toggle terminal (workspace)")
mk("n", "<leader>tt", A.terminal.open_terminal_cwd, "terminal: toggle terminal (cwd)")
---------------------------------------------------------------------------------------#[t]merinal--

--#[t]oggle-----------------------------------------------------------------------------------------
mk("n", "<leader>tfc", A.toggle.flight_copilot, "toggle: copilot")
mk("n", "<leader>tul", A.toggle.relative_line_number, "toggle: relative line number")
mk("n", "<leader>tuT", A.toggle.transparency, "toggle: transparency")
mk("n", "<leader>tut", A.toggle.theme, "toggle: theme")
mk("n", "<leader>tuw", A.toggle.wrap, "toggle: wrap")
-----------------------------------------------------------------------------------------#[t]oggle--

--#[u]i---------------------------------------------------------------------------------------------
mk("n", "<leader>uI", A.ui.show_inspect_tree, "ui: show inspect tree")
mk("n", "<leader>ui", A.ui.show_inspect_pos, "ui: show inspect pos")
mk("n", "<leader>un", A.ui.dismiss_notifications, "ui: dismiss all notifications")
---------------------------------------------------------------------------------------------#[u]i--

--#[w]indow-----------------------------------------------------------------------------------------
mk("n", "<leader>ww", A.window.focus_window_with_picker, "window: focus window (with picker)", true)
mk("n", "<leader>ws", A.window.swap_window_with_picker, "window: swap window (with picker)", true)
mk("n", "<leader>wp", A.window.project_window_with_picker, "window: project window (with picker)", true)
mk("n", "<leader>wj", A.window.split_window_horizontal, "window: split window horizontally", true)
mk("n", "<leader>wl", A.window.split_window_vertical, "window: split window vertically", true)
mk("n", "<leader>wH", A.window.resize_window_vertical_minus, "window: resize -(v:count) vertically.", true)
mk("n", "<leader>wJ", A.window.resize_window_horizontal_minus, "window: resize -(v:count) horizontally.", true)
mk("n", "<leader>wK", A.window.resize_window_horizontal_plus, "window: resize +(v:count) horizontally.", true)
mk("n", "<leader>wL", A.window.resize_window_vertical_plus, "window: resize +(v:count) vertically.", true)
mk("n", "<leader>wd", A.window.close_window_current, "window: close current window", true)
mk("n", "<leader>wo", A.window.close_window_others, "window: close others", true)
-----------------------------------------------------------------------------------------#[w]indow--

--#[x] diagnostic-----------------------------------------------------------------------------------
mk("n", "<leader>xd", A.diagnostic.toggle_document_diagnositics, "diagnostic: open diagnostics (document)")
mk("n", "<leader>xD", A.diagnostic.toggle_workspace_diagnostics, "diagnostic: open diagnostics (workspace)")
mk("n", "<leader>xL", A.diagnostic.toggle_loclist, "diagnostic: open location list (Trouble)")
mk("n", "<leader>xl", A.diagnostic.open_line_diagnostics, "diagnostic: open diagnostics(line)")
mk("n", "<leader>xq", A.diagnostic.toggle_quickfix, "diagnostic: open quickfix list (Trouble)")
-----------------------------------------------------------------------------------#[x] diagnostic--
