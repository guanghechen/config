---@class ghc.action.git.util
local util = {
  path = require("ghc.core.util.path"),
}

---@class ghc.action.git
local M = {}

function M.open_lazygit_workspace()
  local cmds = {
    "cd " .. '"' .. util.path.workspace() .. '"',
    "lazygit",
  }

  require("nvchad.term").toggle({
    id = "lazygit",
    pos = "float",
    cmd = table.concat(cmds, " && "),
  })
end

return M
