---@class guanghechen.keymap.actions
local A = {
  diagnostic = require("guanghechen.command.diagnostic"),
  explorer = require("guanghechen.command.explorer"),
  ui = require("guanghechen.command.ui"),
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
--- quick access widgets (diagnostic, explorer, terminal)
mk({ "n", "v" }, "<leader>1", A.explorer.toggle_explorer_file_cwd, "explorer: files (cwd)")
mk({ "n", "v" }, "<leader>2", ghc.command.search_files.open_search, "search: search/replace")
mk({ "n", "v" }, "<leader>3", A.explorer.toggle_explorer_git_cwd, "explorer: git (cwd)")
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

--#[u]i---------------------------------------------------------------------------------------------
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
