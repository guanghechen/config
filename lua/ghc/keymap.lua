---@class ghc.keymap.actions
local A = {
  bookmark = require("ghc.core.action.bookmark"),
  diagnostic = require("ghc.core.action.diagnostic"),
  explorer = require("ghc.core.action.explorer"),
  find = require("ghc.core.action.find"),
  file = require("ghc.core.action.file"),
  git = require("ghc.core.action.git"),
  replace = require("ghc.core.action.replace"),
  search = require("ghc.core.action.search"),
  terminal = require("ghc.core.action.terminal"),
  ui = require("ghc.core.action.ui"),
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
--- better access git from nvim
mk({ "i", "n", "t", "v" }, "<C-b>g", A.git.open_lazygit_cwd, "git: open lazygit (cwd)", true)
mk({ "i", "n", "t", "v" }, "<M-g>", A.git.open_lazygit_cwd, "git: open lazygit (cwd)", true)

--- better access terminal
mk({ "i", "n", "t", "v" }, "<C-b>t", A.terminal.open_terminal_cwd, "terminal: toggle terminal (cwd)")
mk({ "i", "n", "t", "v" }, "<M-t>", A.terminal.open_terminal_cwd, "terminal: toggle terminal (cwd)")
---------------------------------------------------------------------------------------#enhance-----

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

--#[t]merinal---------------------------------------------------------------------------------------
mk("n", "<leader>tT", A.terminal.open_terminal_workspace, "terminal: toggle terminal (workspace)")
mk("n", "<leader>tt", A.terminal.open_terminal_cwd, "terminal: toggle terminal (cwd)")
---------------------------------------------------------------------------------------#[t]merinal--

--#[u]i---------------------------------------------------------------------------------------------
mk("n", "<leader>uI", A.ui.show_inspect_tree, "ui: show inspect tree")
mk("n", "<leader>ui", A.ui.show_inspect_pos, "ui: show inspect pos")
mk("n", "<leader>un", A.ui.dismiss_notifications, "ui: dismiss all notifications")
---------------------------------------------------------------------------------------------#[u]i--

--#[x] diagnostic-----------------------------------------------------------------------------------
mk("n", "<leader>xd", A.diagnostic.toggle_document_diagnositics, "diagnostic: open diagnostics (document)")
mk("n", "<leader>xD", A.diagnostic.toggle_workspace_diagnostics, "diagnostic: open diagnostics (workspace)")
mk("n", "<leader>xL", A.diagnostic.toggle_loclist, "diagnostic: open location list (Trouble)")
mk("n", "<leader>xl", A.diagnostic.open_line_diagnostics, "diagnostic: open diagnostics(line)")
mk("n", "<leader>xq", A.diagnostic.toggle_quickfix, "diagnostic: open quickfix list (Trouble)")
mk("n", "[d", A.diagnostic.goto_prev_diagnostic, "diagnostic: goto prev diagnostic", true)
mk("n", "]d", A.diagnostic.goto_next_diagnostic, "diagnostic: goto next Diagnostic", true)
mk("n", "[e", A.diagnostic.goto_prev_error, "diagnostic: goto prev error", true)
mk("n", "]e", A.diagnostic.goto_next_error, "diagnostic: goto next error", true)
mk("n", "[q", A.diagnostic.toggle_previous_quickfix_item, "diagnostic: goto previous quickfix", true)
mk("n", "]q", A.diagnostic.toggle_next_quickfix_item, "diagnostic: goto next quickfix", true)
mk("n", "[w", A.diagnostic.goto_prev_warn, "diagnostic: goto prev warning", true)
mk("n", "]w", A.diagnostic.goto_next_warn, "diagnostic: goto next warning", true)
-----------------------------------------------------------------------------------#[x] diagnostic--
