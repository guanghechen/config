---@class ghc.core.action.search.live_grep
local util = {
  path = require("ghc.core.util.path"),
}

---@class ghc.core.action.search
local M = {}

function M.live_grep_with_args_workspace()
  require("telescope").extensions.live_grep_args.live_grep_args({
    cwd = util.path.workspace(),
    workspace = "CWD",
    show_untracked = true,
    prompt_title = "search: Grep with args (workspace)",
  })
end

function M.live_grep_with_args_cwd()
  require("telescope").extensions.live_grep_args.live_grep_args({
    cwd = util.path.cwd(),
    workspace = "CWD",
    show_untracked = true,
    prompt_title = "search: Grep with args (cwd)",
  })
end

function M.live_grep_with_args_current()
  require("telescope").extensions.live_grep_args.live_grep_args({
    cwd = util.path.current(),
    workspace = "CWD",
    show_untracked = true,
    prompt_title = "search grep with args (current directory)",
  })
end

return M
