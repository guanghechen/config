---@class ghc.keymap.actions
local actions = {
  bookmark = require("ghc.core.action.bookmark"),
  buffer = require("ghc.core.action.buffer"),
  diagnostic = require("ghc.core.action.diagnostic"),
  explorer = require("ghc.core.action.explorer"),
  find = require("ghc.core.action.find"),
  file = require("ghc.core.action.file"),
  git = require("ghc.core.action.git"),
  search = require("ghc.core.action.search"),
  session = require("ghc.core.action.session"),
  tab = require("ghc.core.action.tab"),
  terminal = require("ghc.core.action.terminal"),
  ui = require("ghc.core.action.ui"),
  window = require("ghc.core.action.window"),
}

---@param mode string
---@param key string
---@param action any
---@param desc string
---@param silent? boolean
local function mapkey(mode, key, action, desc, silent)
  vim.keymap.set(mode, key, action, { noremap = true, silent = silent ~= nil and silent or false, desc = desc })
end

--#enhance------------------------------------------------------------------------------------------
-- better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- better up/down
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "Next Search Result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "Prev Search Result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })

mapkey("n", "<Esc>", "<cmd>noh<cr><esc>", "Remove search highlights", true) -- Clear search with <esc>

mapkey("t", "<Esc><Esc>", "<C-\\><C-n>", "terminal: Exit terminal mode", true) -- Exit terminal

-- keywordprg
vim.keymap.set("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keywordprg" })

-- better format: https://github.com/stevearc/conform.nvim/issues/372#issuecomment-2066778074
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
vim.keymap.set({ "n", "v" }, "=", "gq", { noremap = true, desc = "Format selected range" })
---------------------------------------------------------------------------------------#enhance-----

--#navigation---------------------------------------------------------------------------------------
----- tab -----
mapkey("n", "[t", actions.tab.goto_tab_left, "tab: Goto left tab", true)
mapkey("n", "]t", actions.tab.goto_tab_right, "tab: Goto right tab", true)

----- buffer -----
mapkey("n", "<leader>1", actions.buffer.open_buffer_1, "buffer: Open buffer 1", true)
mapkey("n", "<leader>2", actions.buffer.open_buffer_2, "buffer: Open buffer 2", true)
mapkey("n", "<leader>3", actions.buffer.open_buffer_3, "buffer: Open buffer 3", true)
mapkey("n", "<leader>4", actions.buffer.open_buffer_4, "buffer: Open buffer 4", true)
mapkey("n", "<leader>5", actions.buffer.open_buffer_5, "buffer: Open buffer 5", true)
mapkey("n", "<leader>6", actions.buffer.open_buffer_6, "buffer: Open buffer 6", true)
mapkey("n", "<leader>7", actions.buffer.open_buffer_7, "buffer: Open buffer 7", true)
mapkey("n", "<leader>8", actions.buffer.open_buffer_8, "buffer: Open buffer 8", true)
mapkey("n", "<leader>9", actions.buffer.open_buffer_9, "buffer: Open buffer 9", true)
mapkey("n", "<leader>0", actions.buffer.open_buffer_10, "buffer: Open buffer 10", true)
mapkey("n", "[b", actions.buffer.open_buffer_left, "buffer: Open left buffer", true)
mapkey("n", "]b", actions.buffer.open_buffer_right, "buffer: Open right buffer", true)

----- diagnostic -----
mapkey("n", "[d", actions.diagnostic.goto_prev_diagnostic, "diagnostic: Goto prev diagnostic", true)
mapkey("n", "]d", actions.diagnostic.goto_next_diagnostic, "diagnostic: Goto next Diagnostic", true)
mapkey("n", "[e", actions.diagnostic.goto_prev_error, "diagnostic: Goto prev error", true)
mapkey("n", "]e", actions.diagnostic.goto_next_error, "diagnostic: Goto next error", true)
mapkey("n", "[q", actions.diagnostic.toggle_previous_quickfix_item, "diagnostic: Goto previous quickfix", true)
mapkey("n", "]q", actions.diagnostic.toggle_next_quickfix_item, "diagnostic: Goto next quickfix", true)
mapkey("n", "[w", actions.diagnostic.goto_prev_warn, "diagnostic: Goto prev warning", true)
mapkey("n", "]w", actions.diagnostic.goto_next_warn, "diagnostic: Goto next warning", true)

----- window -----
mapkey("i", "<C-b>h", actions.window.focus_window_left, "window: Focus on the left window", true)
mapkey("i", "<C-b>j", actions.window.focus_window_bottom, "window: Focus on the bottom window", true)
mapkey("i", "<C-b>k", actions.window.focus_window_top, "window: Focus on the top window", true)
mapkey("i", "<C-b>l", actions.window.focus_window_right, "window: Focus on the right window", true)
mapkey("n", "<C-b>h", actions.window.focus_window_left, "window: Focus on the left window", true)
mapkey("n", "<C-b>j", actions.window.focus_window_bottom, "window: Focus on the bottom window", true)
mapkey("n", "<C-b>k", actions.window.focus_window_top, "window: Focus on the top window", true)
mapkey("n", "<C-b>l", actions.window.focus_window_right, "window: Focus on the right window", true)
mapkey("i", "<M-b>h", actions.window.focus_window_left, "window: Focus on the left window", true)
mapkey("i", "<M-b>j", actions.window.focus_window_bottom, "window: Focus on the bottom window", true)
mapkey("i", "<M-b>k", actions.window.focus_window_top, "window: Focus on the top window", true)
mapkey("i", "<M-b>l", actions.window.focus_window_right, "window: Focus on the right window", true)
mapkey("n", "<M-b>h", actions.window.focus_window_left, "window: Focus on the left window", true)
mapkey("n", "<M-b>j", actions.window.focus_window_bottom, "window: Focus on the bottom window", true)
mapkey("n", "<M-b>k", actions.window.focus_window_top, "window: Focus on the top window", true)
mapkey("n", "<M-b>l", actions.window.focus_window_right, "window: Focus on the right window", true)
mapkey("n", "<leader>h", actions.window.focus_window_left, "window: Focus on the left window", true)
mapkey("n", "<leader>j", actions.window.focus_window_bottom, "window: Focus on the bottom window", true)
mapkey("n", "<leader>k", actions.window.focus_window_top, "window: Focus on the top window", true)
mapkey("n", "<leader>l", actions.window.focus_window_right, "window: Focus on the right window", true)
---------------------------------------------------------------------------------------#navigation--

--[#]buffer-----------------------------------------------------------------------------------------
mapkey("n", "<leader>b1", actions.buffer.open_buffer_1, "buffer: Open buffer 1", true)
mapkey("n", "<leader>b2", actions.buffer.open_buffer_2, "buffer: Open buffer 2", true)
mapkey("n", "<leader>b3", actions.buffer.open_buffer_3, "buffer: Open buffer 3", true)
mapkey("n", "<leader>b4", actions.buffer.open_buffer_4, "buffer: Open buffer 4", true)
mapkey("n", "<leader>b5", actions.buffer.open_buffer_5, "buffer: Open buffer 5", true)
mapkey("n", "<leader>b6", actions.buffer.open_buffer_6, "buffer: Open buffer 6", true)
mapkey("n", "<leader>b7", actions.buffer.open_buffer_7, "buffer: Open buffer 7", true)
mapkey("n", "<leader>b8", actions.buffer.open_buffer_8, "buffer: Open buffer 8", true)
mapkey("n", "<leader>b9", actions.buffer.open_buffer_9, "buffer: Open buffer 9", true)
mapkey("n", "<leader>b0", actions.buffer.open_buffer_10, "buffer: Open buffer 10", true)
mapkey("n", "<leader>b[", actions.buffer.open_buffer_left, "buffer: Open left buffer", true)
mapkey("n", "<leader>b]", actions.buffer.open_buffer_right, "buffer: Open right buffer", true)
mapkey("n", "<leader>ba", actions.buffer.close_buffer_all, "buffer: Close all buffers", true)
mapkey("n", "<leader>bb", actions.buffer.open_buffer_last, "buffer: Open last buffer", true)
mapkey("n", "<leader>bd", actions.buffer.close_buffer, "buffer: Close current buffer", true)
mapkey("n", "<leader>bh", actions.buffer.close_buffer_to_leftest, "buffer: Close buffers to the leftest", true)
mapkey("n", "<leader>bl", actions.buffer.close_buffer_to_rightest, "buffer: Close buffers to the rightest", true)
mapkey("n", "<leader>bn", actions.buffer.new_buffer, "buffer: New buffer", true)
mapkey("n", "<leader>bo", actions.buffer.close_buffer_others, "buffer: Close other buffers", true)
-----------------------------------------------------------------------------------------#[b]uffer--

--#[c]ode-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------#[c]ode--

--#[e]xplorer---------------------------------------------------------------------------------------
mapkey("n", "<leader>eB", actions.explorer.show_buffer_explorer_workspace, "explorer: Buffers (workspace)")
mapkey("n", "<leader>eb", actions.explorer.show_buffer_explorer_cwd, "explorer: Buffers (cwd)")
mapkey("n", "<leader>ee", actions.explorer.focus_or_toggle_explorer, "explorer: Focus or toggle")
mapkey("n", "<leader>eF", actions.explorer.show_file_explorer_workspace, "explorer: Files (workspace)")
mapkey("n", "<leader>ef", actions.explorer.show_file_explorer_cwd, "explorer: Files (cwd)")
mapkey("n", "<leader>eG", actions.explorer.show_git_explorer_workspace, "explorer: Git changed files (workspace)")
mapkey("n", "<leader>eg", actions.explorer.show_git_explorer_cwd, "explorer: Git changed files (cwd)")
mapkey("n", "<leader>er", actions.explorer.reveal_file_explorer, "explorer: Reveal file explorer")
mapkey("n", "<leader>et", actions.explorer.toggle_explorer, "explorer: Toggle")
---------------------------------------------------------------------------------------#[e]xplorer--

--#[f]ile-------------------------------------------------------------------------------------------
mapkey("n", "<leader>fn", actions.file.new_file, "File: New File")
-------------------------------------------------------------------------------------------#[f]ile--

--#[f]ind-------------------------------------------------------------------------------------------
mapkey("n", "<leader>fb", actions.find.find_buffers, "find: Buffers")
mapkey("n", "<leader>fE", actions.find.find_explorer_workspace, "find: File explorer (from workspace)")
mapkey("n", "<leader>fe", actions.find.find_explorer_current, "find: File explorer (from current directory)")
mapkey("n", "<leader>fF", actions.find.find_files_workspace, "find: files (workspace)")
mapkey("n", "<leader>ff", actions.find.find_files_cwd, "find: Files (cwd)")
mapkey("n", "<leader>fg", actions.find.find_files_git, "find: Files (git)")
mapkey("n", "<leader>fm", actions.find.find_bookmark_workspace, "find: bookmarks")
mapkey("n", "<leader>fR", actions.find.find_frecency_workspace, "find: Recent (repo)")
mapkey("n", "<leader>fr", actions.find.find_frecency_cwd, "find: Recent (cwd)")
mapkey("n", "<leader><leader>", actions.find.find_frecency_cwd, "find: Recent (cwd)")
-------------------------------------------------------------------------------------------#[f]ind--

--#[g]it--------------------------------------------------------------------------------------------
mapkey("n", "<leader>gG", actions.git.open_lazygit_workspace, "git: Open lazygit (workspace)", true)
mapkey("n", "<leader>gg", actions.git.open_lazygit_cwd, "git: Open lazygit (cwd)", true)
mapkey("n", "<leader>gf", actions.git.open_lazygit_file_history, "git: Open lazygit file history", true)
-------------------------------------------------------------------------------------------#[g]it---

--#book[m]ark---------------------------------------------------------------------------------------
mapkey("n", "<leader>mm", actions.bookmark.toggle_bookmark_on_current_line, "bookmark: toggle bookmark (current line)")
mapkey("n", "<leader>me", actions.bookmark.edit_bookmark_annotation_on_current_line, "bookmark: edit bookmark (current line)")
mapkey("n", "<leader>mc", actions.bookmark.clear_bookmark_on_current_buffer, "bookmark: clear bookmark (current buffer)")
mapkey("n", "<leader>m[", actions.bookmark.goto_prev_bookmark_on_current_buffer, "bookmark: goto prev bookmark (current buffer)")
mapkey("n", "<leader>m]", actions.bookmark.goto_next_bookmark_on_current_buffer, "bookmark: goto next bookmark (current buffer)")
mapkey("n", "<leader>ml", actions.bookmark.open_bookmarks_into_quickfix, "bookmark: open bookmark list (quickfix)")
---------------------------------------------------------------------------------------#book[m]ark--

--#[q]uit/session-------------------------------------------------------------------------------------------
mapkey("n", "<leader>qq", actions.session.quit_all, "quit: Quit all", true)
mapkey("n", "<leader>qL", actions.session.session_load, "session: Restore autosaved session", true)
mapkey("n", "<leader>ql", actions.session.session_load, "session: Restore session", true)
mapkey("n", "<leader>qs", actions.session.session_save, "session: Save session", true)
mapkey("n", "<leader>qC", actions.session.session_clear_all, "session: Clear all sessions", true)
-------------------------------------------------------------------------------------------#[q]uit--

--#[s]earch-----------------------------------------------------------------------------------------
mapkey("n", "<leader>sG", actions.search.live_grep_with_args_workspace, "search: Grep (workspace)")
mapkey("n", "<leader>sg", actions.search.live_grep_with_args_cwd, "search: Grep (cwd)")
mapkey("n", "<leader>sS", actions.search.grep_selected_text_workspace, "search: Grep word (workspace)")
mapkey("n", "<leader>ss", actions.search.grep_selected_text_cwd, "search: Grep word (cwd)")
mapkey("v", "<leader>sS", actions.search.grep_selected_text_workspace, "search: Grep word (workspace)")
mapkey("v", "<leader>ss", actions.search.grep_selected_text_cwd, "search: Grep word (cwd)")
-----------------------------------------------------------------------------------------#[s]earch--

--#[t]ab--------------------------------------------------------------------------------------------
mapkey("n", "<leader>t1", actions.tab.goto_tab_1, "tab: Goto tab 1", true)
mapkey("n", "<leader>t2", actions.tab.goto_tab_2, "tab: Goto tab 2", true)
mapkey("n", "<leader>t3", actions.tab.goto_tab_3, "tab: Goto tab 3", true)
mapkey("n", "<leader>t4", actions.tab.goto_tab_4, "tab: Goto tab 4", true)
mapkey("n", "<leader>t5", actions.tab.goto_tab_5, "tab: Goto tab 5", true)
mapkey("n", "<leader>t6", actions.tab.goto_tab_6, "tab: Goto tab 6", true)
mapkey("n", "<leader>t7", actions.tab.goto_tab_7, "tab: Goto tab 7", true)
mapkey("n", "<leader>t8", actions.tab.goto_tab_8, "tab: Goto tab 8", true)
mapkey("n", "<leader>t9", actions.tab.goto_tab_9, "tab: Goto tab 9", true)
mapkey("n", "<leader>t0", actions.tab.goto_tab_10, "tab: Goto tab 10", true)
mapkey("n", "<leader>t[", actions.tab.goto_tab_left, "tab: Goto left tab", true)
mapkey("n", "<leader>t]", actions.tab.goto_tab_right, "tab: Goto right tab", true)
mapkey("n", "<leader>tN", actions.tab.open_tab_new, "tab: New tab", true)
mapkey("n", "<leader>tn", actions.tab.open_tab_new_with_current_buf, "tab: New tab with current buf", true)
mapkey("n", "<leader>td", actions.tab.close_tab_current, "tab: Close current", true)
mapkey("n", "<leader>th", actions.tab.close_tab_to_leftest, "tab: Close tabs to the leftest", true)
mapkey("n", "<leader>tl", actions.tab.close_tab_to_rightest, "tab: Close tabs to the rightest", true)
mapkey("n", "<leader>to", actions.tab.close_tab_others, "tab: Close other tabs", true)
--------------------------------------------------------------------------------------------#[t]ab--

--#[t]merinal---------------------------------------------------------------------------------------
mapkey("n", "<leader>tT", actions.terminal.open_terminal_workspace, "terminal: Toggle terminal (workspace)")
mapkey("n", "<leader>tt", actions.terminal.open_terminal_cwd, "terminal: Toggle terminal (cwd)")
---------------------------------------------------------------------------------------#[t]merinal--

--#[u]i---------------------------------------------------------------------------------------------
mapkey("n", "<leader>ui", actions.ui.show_inspect_pos, "ui: Show inspect pos")
mapkey("n", "<leader>un", actions.ui.dismiss_notifications, "ui: Dismiss all notifications")
mapkey("n", "<leader>ut", actions.ui.toggle_theme, "ui: Toggle theme")
---------------------------------------------------------------------------------------------#[u]i--

--#[w]indow-----------------------------------------------------------------------------------------
mapkey("n", "<leader>wh", actions.window.focus_window_left, "window: Focus on the left window", true)
mapkey("n", "<leader>wj", actions.window.focus_window_bottom, "window: Focus on the bottom window", true)
mapkey("n", "<leader>wk", actions.window.focus_window_top, "window: Focus on the top window", true)
mapkey("n", "<leader>wl", actions.window.focus_window_right, "window: Focus on the right window", true)
mapkey("n", "<leader>ww", actions.window.focus_window_with_picker, "window: Focus window (with picker)", true)
mapkey("n", "<leader>ws", actions.window.swap_window_with_picker, "window: Swap window (with picker)", true)
mapkey("n", "<leader>wp", actions.window.project_window_with_picker, "window: Project window (with picker)", true)
mapkey("n", "<leader>w-", actions.window.split_window_horizontal, "window: Split window horizontally", true)
mapkey("n", "<leader>w|", actions.window.split_window_vertical, "window: Split window vertically", true)
mapkey("n", "<leader>wJ", actions.window.split_window_horizontal, "window: Split window horizontally", true)
mapkey("n", "<leader>wL", actions.window.split_window_vertical, "window: Split window vertically", true)
mapkey("n", "<leader>w<Left>", actions.window.resize_window_vertical_minus, "window: Resize -(v:count) vertically.", true)
mapkey("n", "<leader>w<Down>", actions.window.resize_window_horizontal_minus, "window: Resize -(v:count) horizontally.", true)
mapkey("n", "<leader>w<Up>", actions.window.resize_window_horizontal_plus, "window: Resize +(v:count) horizontally.", true)
mapkey("n", "<leader>w<Right>", actions.window.resize_window_vertical_plus, "window: Resize +(v:count) vertically.", true)
mapkey("n", "<leader>wd", actions.window.close_window_current, "window: close current window", true)
mapkey("n", "<leader>wo", actions.window.close_window_others, "window: close others", true)
-----------------------------------------------------------------------------------------#[w]indow--

--#[x] diagnostic-----------------------------------------------------------------------------------
mapkey("n", "<leader>xd", actions.diagnostic.toggle_document_diagnositics, "diagnostic: Open diagnostics (document)")
mapkey("n", "<leader>xD", actions.diagnostic.toggle_workspace_diagnostics, "diagnostic: Open diagnostics (workspace)")
mapkey("n", "<leader>xL", actions.diagnostic.toggle_loclist, "diagnostic: Open location list (Trouble)")
mapkey("n", "<leader>xl", actions.diagnostic.open_line_diagnostics, "diagnostic: Open diagnostics(line)")
mapkey("n", "<leader>xq", actions.diagnostic.toggle_quickfix, "diagnostic: Open quickfix list (Trouble)")
-----------------------------------------------------------------------------------#[x] diagnostic--
