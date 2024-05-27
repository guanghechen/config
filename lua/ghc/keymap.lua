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
mk({ "n", "v" }, "<leader>eB", A.explorer.toggle_explorer_buffer_workspace, "explorer: buffers (workspace)")
mk({ "n", "v" }, "<leader>eb", A.explorer.toggle_explorer_buffer_cwd, "explorer: buffers (cwd)")
mk({ "n", "v" }, "<leader>ee", A.explorer.toggle_explorer_last, "explorer: last")
mk({ "n", "v" }, "<leader>eF", A.explorer.toggle_explorer_file_workspace, "explorer: files (workspace)")
mk({ "n", "v" }, "<leader>ef", A.explorer.toggle_explorer_file_cwd, "explorer: files (cwd)")
mk({ "n", "v" }, "<leader>eG", A.explorer.toggle_explorer_git_workspace, "explorer: git (workspace)")
mk({ "n", "v" }, "<leader>eg", A.explorer.toggle_explorer_git_cwd, "explorer: git (cwd)")
mk({ "n", "v" }, "<leader>er", A.explorer.reveal_file_explorer, "explorer: reveal file")
mk({ "n", "v" }, "<leader>et", A.explorer.toggle_explorers, "explorer: toggle")
---------------------------------------------------------------------------------------#[e]xplorer--

--#[f]ind-------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>fb", A.find.find_buffers, "find: buffers")
mk({ "n", "v" }, "<leader>fE", A.find.find_explorer_workspace, "find: file explorer (from workspace)")
mk({ "n", "v" }, "<leader>fe", A.find.find_explorer_current, "find: file explorer (from current directory)")
mk({ "n", "v" }, "<leader>fF", A.find.find_file_force, "find: files (force)")
mk({ "n", "v" }, "<leader>ff", A.find.find_file, "find: files")
mk({ "n", "v" }, "<leader>fg", A.find.find_file_git, "find: files (git)")
mk({ "n", "v" }, "<leader>fh", A.find.find_highlights, "find: highlights")
mk({ "n", "v" }, "<leader>fm", A.find.find_bookmark_workspace, "find: bookmarks")
mk({ "n", "v" }, "<leader>fq", A.find.find_quickfix_history, "find: quickfix history")
mk({ "n", "v" }, "<leader>fr", A.find.find_recent, "find: recent")
mk({ "n", "v" }, "<leader>fv", A.find.find_vim_options, "find: vim options")
mk({ "n", "v" }, "<leader><leader>", A.find.find_recent, "find recent")
-------------------------------------------------------------------------------------------#[f]ind--

--#[g]it--------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>gg", A.git.open_diffview, "git: open diff view", true)
mk({ "n", "v" }, "<leader>gf", A.git.open_diffview_filehistory, "git: open file history", true)
-------------------------------------------------------------------------------------------#[g]it---

--#book[m]ark---------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>mm", A.bookmark.toggle_on_current_line, "bookmark: toggle bookmark (current line)")
mk({ "n", "v" }, "<leader>me", A.bookmark.edit_annotation_on_current_line, "bookmark: edit bookmark (current line)")
mk({ "n", "v" }, "<leader>mc", A.bookmark.clear_marks_buffer, "bookmark: clear bookmark (current buffer)")
mk({ "n", "v" }, "<leader>m[", A.bookmark.goto_prev_mark_buffer, "bookmark: goto prev bookmark (current buffer)")
mk({ "n", "v" }, "<leader>m]", A.bookmark.goto_next_mark_buffer, "bookmark: goto next bookmark (current buffer)")
mk({ "n", "v" }, "<leader>ml", A.bookmark.open_bookmarks_into_quickfix, "bookmark: open bookmark list (quickfix)")
---------------------------------------------------------------------------------------#book[m]ark--

--#[r]eplace----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>rR", A.replace.replace_word_workspace, "replace: word (workspace)")
mk({ "n", "v" }, "<leader>rr", A.replace.replace_word_current_file, "replace: word (current file)")
mk("v", "<leader>rti", A.replace.toggle_case_sensitive, "replace: toggle case sensitive")
----------------------------------------------------------------------------------------#[r]eplace--

--#[s]earch-----------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>sw", A.search.grep_selected_text_workspace, "search: grep word (workspace)")
mk({ "n", "v" }, "<leader>sc", A.search.grep_selected_text_cwd, "search: grep word (cwd)")
mk({ "n", "v" }, "<leader>sd", A.search.grep_selected_text_directory, "search: grep word (directory)")
mk({ "n", "v" }, "<leader>sb", A.search.grep_selected_text_buffer, "search: grep word (buffer)")
mk({ "n", "v" }, "<leader>ss", A.search.grep_selected_text, "search: grep word")
-----------------------------------------------------------------------------------------#[s]earch--

--#[t]merinal---------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>tT", A.terminal.open_terminal_workspace, "terminal: toggle terminal (workspace)")
mk({ "n", "v" }, "<leader>tt", A.terminal.open_terminal_cwd, "terminal: toggle terminal (cwd)")
---------------------------------------------------------------------------------------#[t]merinal--

--#[u]i---------------------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>uI", A.ui.show_inspect_tree, "ui: show inspect tree")
mk({ "n", "v" }, "<leader>ui", A.ui.show_inspect_pos, "ui: show inspect pos")
mk({ "n", "v" }, "<leader>un", A.ui.dismiss_notifications, "ui: dismiss all notifications")
---------------------------------------------------------------------------------------------#[u]i--

--#[x] diagnostic-----------------------------------------------------------------------------------
mk({ "n", "v" }, "<leader>xd", A.diagnostic.toggle_document_diagnositics, "diagnostic: open diagnostics (document)")
mk({ "n", "v" }, "<leader>xD", A.diagnostic.toggle_workspace_diagnostics, "diagnostic: open diagnostics (workspace)")
mk({ "n", "v" }, "<leader>xL", A.diagnostic.toggle_loclist, "diagnostic: open location list (Trouble)")
mk({ "n", "v" }, "<leader>xl", A.diagnostic.open_line_diagnostics, "diagnostic: open diagnostics(line)")
mk({ "n", "v" }, "<leader>xq", A.diagnostic.toggle_quickfix, "diagnostic: open quickfix list (Trouble)")
mk({ "n", "v" }, "[d", A.diagnostic.goto_prev_diagnostic, "diagnostic: goto prev diagnostic", true)
mk({ "n", "v" }, "]d", A.diagnostic.goto_next_diagnostic, "diagnostic: goto next Diagnostic", true)
mk({ "n", "v" }, "[e", A.diagnostic.goto_prev_error, "diagnostic: goto prev error", true)
mk({ "n", "v" }, "]e", A.diagnostic.goto_next_error, "diagnostic: goto next error", true)
mk({ "n", "v" }, "[q", A.diagnostic.toggle_previous_quickfix_item, "diagnostic: goto previous quickfix", true)
mk({ "n", "v" }, "]q", A.diagnostic.toggle_next_quickfix_item, "diagnostic: goto next quickfix", true)
mk({ "n", "v" }, "[w", A.diagnostic.goto_prev_warn, "diagnostic: goto prev warning", true)
mk({ "n", "v" }, "]w", A.diagnostic.goto_next_warn, "diagnostic: goto next warning", true)
-----------------------------------------------------------------------------------#[x] diagnostic--
