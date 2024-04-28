---@class ghc.core.action.terminal.util
local util = {
  path = require("ghc.core.util.path"),
}

---@class ghc.core.action.terminal
local M = {}

function M.open_terminal_workspace()
  LazyVim.terminal(nil, {
    cwd = util.path.workspace(),
    border = "rounded",
    persistent = true,
  })
end

function M.open_terminal_cwd()
  LazyVim.terminal(nil, {
    cwd = util.path.cwd(),
    border = "rounded",
    persistent = true,
  })
end

function M.open_terminal_current()
  LazyVim.terminal(nil, {
    cwd = util.path.current(),
    border = "rounded",
  })
end

return M
