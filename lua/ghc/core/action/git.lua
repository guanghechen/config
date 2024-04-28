---@class ghc.action.git.util
local util = {
  path = require("ghc.core.util.path"),
}

---@class ghc.action.git
local M = {}

function M.open_lazygit_workspace()
  LazyVim.lazygit({
    cwd = util.path.workspace(),
  })
end

function M.open_lazygit_cwd()
  LazyVim.lazygit({
    cwd = util.path.cwd(),
  })
end

function M.open_lazygit_file_history()
  local git_path = vim.api.nvim_buf_get_name(0)
  LazyVim.lazygit({
    args = {
      "-f",
      vim.trim(git_path)
    }
  })
end

return M
