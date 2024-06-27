local action_autocmd = require("guanghechen.core.action.autocmd")

action_autocmd.autocmd_startup()
action_autocmd.autocmd_checktime() -- Check if we need to reload the file when it changed
action_autocmd.autocmd_close_with_q({ -- close some filetypes with <q>
  pattern = {
    "checkhealth",
    "git",
    "help",
    "lspinfo",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "neo-tree",
    "notify",
    "PlenaryTestPopup",
    "qf",
    "spectre_panel",
    "startuptime",
    "term",
    "tsplayground",
    "Trouble",
  },
})
action_autocmd.autocmd_create_dirs()
action_autocmd.autocmd_highlight_yank()
action_autocmd.autocmd_remember_last_tabnr()
action_autocmd.autocmd_resize_splits() -- resize splits if window got resized
action_autocmd.autocmd_session_autosave() -- auto save session
action_autocmd.autocmd_show_lsp_progress()() -- show lsp progress
action_autocmd.autocmd_toggle_linenumber()
action_autocmd.autocmd_goto_last_location({ exclude = { "gitcommit" } })
action_autocmd.autocmd_unlist_buffer({ pattern = { "man" } }) -- make it easier to close man-files when opened inline

--#format
action_autocmd.autocmd_enable_wrap({ pattern = { "markdown", "text" } })
action_autocmd.autocmd_enable_spell({ pattern = { "gitcommit", "html", "lua", "text", "typescript" } })
action_autocmd.autocmd_set_fileformat({
  pattern = {
    "css",
    "html",
    "javascript",
    "json",
    "markdown",
    "text",
    "tmux",
    "toml",
    "typescript",
  },
})

--#filetype
action_autocmd.autocmd_set_filetype({
  filetype_map = {
    tmux = { "*.tmux.conf" },
    bash = { "*.fzfrc", "*.ripgreprc" },
  },
})

--#tabstop
action_autocmd.autocmd_set_tabstop({
  pattern = { "markdown" },
  width = 2,
})

--#window
action_autocmd.autocmd_window_update_history()
