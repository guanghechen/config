local action_autocmd = require("guanghechen.command.autocmd")

action_autocmd.autocmd_goto_last_location({ exclude = { "gitcommit" } })

--#format
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
