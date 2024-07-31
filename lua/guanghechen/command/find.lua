---@class guanghechen.command.find
local M = {}

---@return nil
function M.find_buffers()
  vim.cmd("Telescope buffers sort_mru=true sort_lastused=true")
end

---@return nil
function M.find_explorer_workspace()
  require("telescope").extensions.file_browser.file_browser({
    cwd = fml.path.workspace(),
    workspace = "CWD",
    show_untracked = true,
    grouped = true,
    initial_mode = "normal",
    prompt_title = "File explorer (workspace)",
  })
end

---@return nil
function M.find_explorer_cwd()
  require("telescope").extensions.file_browser.file_browser({
    cwd = fml.path.cwd(),
    workspace = "CWD",
    select_buffer = true,
    show_untracked = true,
    grouped = true,
    initial_mode = "normal",
    prompt_title = "File explorer (from cwd)",
  })
end

---@return nil
function M.find_explorer_current()
  local absolute_path = fml.path.current_directory()
  local relative_path = fml.path.relative(fml.path.cwd(), absolute_path)
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

---@return nil
function M.find_file_git()
  require("telescope.builtin").git_files({
    cwd = fml.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find files (git)",
    show_untracked = true,
    initial_mode = "insert",
  })
end

---@return nil
function M.find_quickfix_history()
  require("telescope.builtin").quickfixhistory({
    cwd = fml.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find quickfix history",
    show_untracked = true,
    initial_mode = "normal",
  })
end

---@return nil
function M.find_vim_options()
  require("telescope.builtin").vim_options({
    cwd = fml.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find vim options",
    show_untracked = true,
    initial_mode = "normal",
  })
end

---@return nil
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
