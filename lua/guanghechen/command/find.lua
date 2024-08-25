---@class guanghechen.command.find
local M = {}

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

return M
