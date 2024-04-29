---@class ghc.core.action.find.util
local util = {
  path = require("ghc.core.util.path"),
}

---@class ghc.core.action.find
local M = {}

function M.find_bookmark_workspace()
  local absolute_path = util.path.workspace()
  local relative_path = util.path.relative(util.path.workspace(), absolute_path)
  require("telescope").extensions.bookmarks.bookmarks({
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
  local absolute_path = util.path.current()
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

function M.find_files_workspace()
  require("telescope.builtin").find_files({
    cwd = util.path.workspace(),
    workspace = "CWD",
    show_untracked = true,
    -- prompt_title = "Find files (" .. util.path.workspace() .. ")",
    prompt_title = "Find files (workspace)",
  })
end

function M.find_files_cwd()
  require("telescope.builtin").find_files({
    cwd = util.path.cwd(),
    workspace = "CWD",
    show_untracked = true,
    -- prompt_title = "Find files (" .. util.path.cwd() .. ")",
    prompt_title = "Find files (cwd)",
  })
end

function M.find_files_current()
  local absolute_path = util.path.current()
  local relative_path = util.path.relative(util.path.cwd(), absolute_path)
  require("telescope.builtin").find_files({
    cwd = absolute_path,
    workspace = "CWD",
    show_untracked = true,
    prompt_title = "Find files (" .. relative_path .. ")",
  })
end

function M.find_files_git()
  require("telescope.builtin").git_files({
    cwd = util.path.workspace(),
    workspace = "CWD",
    prompt_title = "Find files (git)",
  })
end

function M.find_frecency_workspace()
  require("telescope").extensions.frecency.frecency({
    cwd = util.path.workspace(),
    workspace = "CWD",
    show_untracked = true,
    -- prompt_title = "Find recent (" .. util.path.workspace() .. ")",
    prompt_title = "Find recent (workspace)",
  })
end

function M.find_frecency_cwd()
  require("telescope").extensions.frecency.frecency({
    cwd = util.path.cwd(),
    workspace = "CWD",
    show_untracked = true,
    -- prompt_title = "Find recent (" .. util.path.cwd() .. ")",
    prompt_title = "Find recent (cwd)",
  })
end

function M.find_frecency_current()
  local absolute_path = util.path.current()
  local relative_path = util.path.relative(util.path.cwd(), absolute_path)
  require("telescope").extensions.frecency.frecency({
    cwd = absolute_path,
    workspace = "CWD",
    show_untracked = true,
    prompt_title = "Find recent (" .. relative_path .. ")",
  })
end

return M
