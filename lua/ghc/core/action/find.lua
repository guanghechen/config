local guanghechen = require("guanghechen")

---@class ghc.core.action.find
local M = {}

function M.find_bookmark_workspace()
  local absolute_path = guanghechen.util.path.workspace()
  local relative_path = guanghechen.util.path.relative(guanghechen.util.path.workspace(), absolute_path)
  require("telescope").extensions.bookmarks.list({
    cwd = absolute_path,
    workspace = "CWD",
    show_untracked = true,
    prompt_title = "Find bookmarks (" .. relative_path .. ")",
  })
end

function M.find_buffers()
  vim.cmd("Telescope buffers sort_mru=true sort_lastused=true")
end

function M.find_explorer_workspace()
  require("telescope").extensions.file_browser.file_browser({
    cwd = guanghechen.util.path.workspace(),
    workspace = "CWD",
    show_untracked = true,
    grouped = true,
    initial_mode = "normal",
    prompt_title = "File explorer (workspace)",
  })
end

function M.find_explorer_cwd()
  require("telescope").extensions.file_browser.file_browser({
    cwd = guanghechen.util.path.cwd(),
    workspace = "CWD",
    select_buffer = true,
    show_untracked = true,
    grouped = true,
    initial_mode = "normal",
    prompt_title = "File explorer (from cwd)",
  })
end

function M.find_explorer_current()
  local absolute_path = guanghechen.util.path.current_directory()
  local relative_path = guanghechen.util.path.relative(guanghechen.util.path.cwd(), absolute_path)
  require("telescope").extensions.file_browser.file_browser({
    cwd = absolute_path,
    workspace = "CWD",
    select_buffer = true,
    show_untracked = true,
    grouped = true,
    initial_mode = "normal",
    prompt_title = "File explorer (from " .. relative_path .. ")",
  })
end

function M.find_file_git()
  require("telescope.builtin").git_files({
    cwd = guanghechen.util.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find files (git)",
    show_untracked = true,
    initial_mode = "insert",
  })
end

function M.find_quickfix_history()
  require("telescope.builtin").quickfixhistory({
    cwd = guanghechen.util.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find quickfix history",
    show_untracked = true,
    initial_mode = "normal",
  })
end

function M.find_vim_options()
  require("telescope.builtin").vim_options({
    cwd = guanghechen.util.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find vim options",
    show_untracked = true,
    initial_mode = "normal",
  })
end

function M.find_highlights()
  require("telescope.builtin").highlights({
    cwd = guanghechen.util.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find vim options",
    show_untracked = true,
    initial_mode = "normal",
  })
end

return M