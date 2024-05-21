local guanghechen = require("guanghechen")
local util_terminal = require("ghc.core.util.terminal")

---@class ghc.core.action.terminal
local M = {}

function M.open_terminal_workspace()
  util_terminal.toggle_terminal({
    id = "workspace-terminal",
    cwd = guanghechen.util.path.workspace(),
  })
end

function M.open_terminal_cwd()
  util_terminal.toggle_terminal({
    id = "cwd-terminal",
    cwd = guanghechen.util.path.cwd(),
  })
end

function M.open_terminal_current()
  util_terminal.toggle_terminal({
    id = guanghechen.util.path.current_directory(),
    cwd = guanghechen.util.path.current_directory(),
  })
end

return M