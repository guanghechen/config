local actions = {
  autocmd = require("ghc.core.action.autocmd"),
}

actions.autocmd.autocmd_clear_jumps()
actions.autocmd.autocmd_checktime() -- Check if we need to reload the file when it changed
actions.autocmd.autocmd_change_dir()
actions.autocmd.autocmd_create_dirs()
actions.autocmd.autocmd_highlight_yank()
actions.autocmd.autocmd_resize_splits() -- resize splits if window got resized
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
actions.autocmd.autocmd_disable_format({ pattern = { "text", "tmux", "toml", "json", "markdown" } })
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
vim.cmd("autocmd BufRead,BufNewFile *.tmux.conf set filetype=tmux")
vim.cmd("autocmd BufRead,BufNewFile *.fzfrc set filetype=bash")

--#plugin
vim.cmd("autocmd User TelescopePreviewerLoaded setlocal number") -- enable numbers in telescope preview.
