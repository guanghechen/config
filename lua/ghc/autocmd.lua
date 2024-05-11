local actions = {
  autocmd = require("ghc.core.action.autocmd"),
}

actions.autocmd.autocmd_clear_jumps()
actions.autocmd.autocmd_checktime() -- Check if we need to reload the file when it changed
actions.autocmd.autocmd_change_dir()
actions.autocmd.autocmd_create_dirs()
actions.autocmd.autocmd_highlight_yank()
actions.autocmd.autocmd_remember_last_tabnr()
actions.autocmd.autocmd_resize_splits() -- resize splits if window got resized
actions.autocmd.autocmd_session_autosave() -- auto save session
actions.autocmd.autocmd_goto_last_location({ exclude = { "gitcommit" } })
actions.autocmd.autocmd_unlist_buffer({ pattern = { "man" } }) -- make it easier to close man-files when opened inline
actions.autocmd.autocmd_close_with_q({ -- close some filetypes with <q>
  pattern = {
    "checkhealth",
    "help",
    "lspinfo",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "notify",
    "PlenaryTestPopup",
    "qf",
    "query",
    "spectre_panel",
    "startuptime",
    "TelescopePrompt",
    "term",
    "tsplayground",
  },
})

--#format
actions.autocmd.autocmd_enable_wrap({ pattern = { "markdown", "text" } })
actions.autocmd.autocmd_enable_spell({ pattern = { "gitcommit", "html", "lua", "text", "typescript" } })
actions.autocmd.autocmd_set_fileformat({
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
actions.autocmd.autocmd_set_filetype({
  filetype_map = {
    tmux = { "*.tmux.conf" },
    bash = { "*.fzfrc", "*.ripgreprc" },
  },
})

--#plugin
vim.cmd("autocmd User TelescopePreviewerLoaded setlocal number") -- enable numbers in telescope preview.
