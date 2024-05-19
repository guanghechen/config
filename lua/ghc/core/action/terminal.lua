local util_path = require("guanghechen.util.path")
local util_terminal = require("ghc.core.util.terminal")

---@class ghc.core.action.terminal
local M = {}

function M.open_terminal_workspace()
  util_terminal.toggle_terminal({
    id = "workspace-terminal",
    cwd = util_path.workspace(),
  })
end

function M.open_terminal_cwd()
  util_terminal.toggle_terminal({
    id = "cwd-terminal",
    cwd = util_path.cwd(),
  })
end

function M.open_terminal_current()
  util_terminal.toggle_terminal({
    id = util_path.current_directory(),
    cwd = util_path.current_directory(),
  })
end

return M
