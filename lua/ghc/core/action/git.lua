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
    border = "none",
  })
end

function M.open_lazygit_cwd()
  local cmd = { "lazygit" }
  util.terminal.open_terminal(cmd, {
    cwd = util.path.cwd(),
    esc_esc = false,
    ctrl_hjkl = false,
    border = "none",
  })
end

return M
