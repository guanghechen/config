---@class ghc.core.action.find
local M = require("ghc.core.action.find.module")

function M.find_bookmark_workspace()
  local absolute_path = fml.path.workspace()
  local relative_path = fml.path.relative(fml.path.workspace(), absolute_path)
  require("telescope").extensions.bookmarks.list({
    cwd = absolute_path,
    workspace = "CWD",
    show_untracked = true,
    prompt_title = "Find bookmarks (" .. relative_path .. ")",
  })
end
