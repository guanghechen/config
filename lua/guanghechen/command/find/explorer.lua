---@class guanghechen.command.find
local M = require("guanghechen.command.find.module")

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
