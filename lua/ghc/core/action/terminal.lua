---@class ghc.core.action.terminal.util
local util = {
  path = require("ghc.core.util.path"),
  terminal = require("ghc.core.util.terminal"),
}

---@class ghc.core.action.terminal
local M = {}

function M.open_terminal_workspace()
  util.terminal.toggle_terminal({
    id = "workspace-terminal",
    cwd = util.path.workspace(),
  })
end

function M.open_terminal_cwd()
  util.terminal.toggle_terminal({
    id = "cwd-terminal",
    cwd = util.path.cwd(),
  })
end

function M.open_terminal_current()
  util.terminal.toggle_terminal({
    id = util.path.current(),
    cwd = util.path.current(),
  })
end

return M
