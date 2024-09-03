local action_autocmd = require("guanghechen.command.autocmd")

action_autocmd.autocmd_goto_last_location({ exclude = { "gitcommit" } })
action_autocmd.autocmd_unlist_buffer({
  pattern = {
    "checkhealth",
    "git",
    "help",
    "lspinfo",
    "man",
    "neotest-output",
    "neotest-output-panel",
    "neotest-summary",
    "neo-tree",
    "notify",
    "PlenaryTestPopup",
    "qf",
    "startuptime",
    "tsplayground",
    "Trouble",
  },
}) -- make it easier to close man-files when opened inline

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
