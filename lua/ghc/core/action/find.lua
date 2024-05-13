---@class ghc.core.action.find.util
local util = {
  path = require("ghc.core.util.path"),
}

---@class ghc.core.action.find
local M = {}

function M.find_bookmark_workspace()
  local absolute_path = util.path.workspace()
  local relative_path = util.path.relative(util.path.workspace(), absolute_path)
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
    cwd = util.path.workspace(),
    workspace = "CWD",
    show_untracked = true,
    grouped = true,
    initial_mode = "normal",
    prompt_title = "File explorer (workspace)",
  })
end

function M.find_explorer_cwd()
  require("telescope").extensions.file_browser.file_browser({
    cwd = util.path.cwd(),
    workspace = "CWD",
    select_buffer = true,
    show_untracked = true,
    grouped = true,
    initial_mode = "normal",
    prompt_title = "File explorer (from cwd)",
  })
end

function M.find_explorer_current()
  local absolute_path = util.path.current_directory()
  local relative_path = util.path.relative(util.path.cwd(), absolute_path)
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

return M
