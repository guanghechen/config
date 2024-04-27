---@class ghc.action.git.util
local util = {
  path = require("ghc.core.util.path"),
  terminal = require("ghc.core.util.terminal"),
}

---@class ghc.action.git
local M = {}

function M.open_lazygit_workspace()
  util.terminal.toggle_terminal({
    id = "lazygit",
    cwd = util.path.workspace(),
    cmd = { "lazygit" },
  })
end

return M
