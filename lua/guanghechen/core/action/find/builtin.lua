---@class guanghechen.core.action.find
local M = require("guanghechen.core.action.find.module")

function M.find_buffers()
  vim.cmd("Telescope buffers sort_mru=true sort_lastused=true")
end

function M.find_file_git()
  require("telescope.builtin").git_files({
    cwd = fml.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find files (git)",
    show_untracked = true,
    initial_mode = "insert",
  })
end

function M.find_quickfix_history()
  require("telescope.builtin").quickfixhistory({
    cwd = fml.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find quickfix history",
    show_untracked = true,
    initial_mode = "normal",
  })
end

function M.find_vim_options()
  require("telescope.builtin").vim_options({
    cwd = fml.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find vim options",
    show_untracked = true,
    initial_mode = "normal",
  })
end

function M.find_highlights()
  require("telescope.builtin").highlights({
    cwd = fml.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find vim options",
    show_untracked = true,
    initial_mode = "normal",
  })
end

return M