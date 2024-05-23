local guanghechen = require("guanghechen")

---@class ghc.core.action.find
local M = require("ghc.core.action.find.module")

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
