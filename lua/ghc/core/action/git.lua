---@class ghc.action.git.util
local util = {
  path = require("ghc.core.util.path"),
  terminal = require("ghc.core.util.terminal"),
}

---@class ghc.action.git
local M = {}

function M.open_lazygit_workspace()
  local cmd = { "lazygit" }
  util.terminal.open_terminal(cmd, {
    cwd = util.path.workspace(),
    esc_esc = false,
    ctrl_hjkl = false,
  })
end

function M.open_lazygit_cwd()
  local cmd = { "lazygit" }
  util.terminal.open_terminal(cmd, {
    cwd = util.path.cwd(),
    esc_esc = false,
    ctrl_hjkl = false,
  })
end

function M.git_blame_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1
  local file = vim.api.nvim_buf_get_name(0)
  local cmd = { "git", "log", "-n", 3, "-u", "-L", line .. ",+1:" .. file }
  return require("lazy.util").float_cmd(cmd, {
    cwd = util.path.cwd(),
    filetype = "git",
    size = {
      width = 0.6,
      height = 0.6,
    },
    border = "rounded",
    esc_esc = false,
    ctrl_hjkl = false,
  })
end

return M
