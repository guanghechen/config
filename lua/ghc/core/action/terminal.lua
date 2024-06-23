local guanghechen = require("guanghechen")
local util_terminal = require("ghc.core.util.terminal")

---@class ghc.core.action.terminal
local M = {}

function M.open_terminal_workspace()
  util_terminal.toggle_terminal(nil, {
    id = "workspace-terminal",
    cwd = guanghechen.util.path.workspace(),
  })
end

function M.open_terminal_cwd()
  util_terminal.toggle_terminal(nil, {
    id = "cwd-terminal",
    cwd = guanghechen.util.path.cwd(),
  })
end

function M.open_terminal_current()
  util_terminal.toggle_terminal(nil, {
    id = guanghechen.util.path.current_directory(),
    cwd = guanghechen.util.path.current_directory(),
  })
end

function M.open_terminal_workspace_tmux()
  if fml.core.os.is_windows() then
    M.open_terminal_workspace()
  else
    local cwd = guanghechen.util.path.workspace()
    local cmd = { "bash", guanghechen.util.path.locate_script_filepath("tmux.sh"), cwd } ---@type string[]
    ---@type LazyTermOpts
    local opts = {
      id = "popup-terminal",
      cwd = cwd,
      float = {
        ft = "term",
        width = 0.8,
        height = 0.8,
        border = "none",
      },
    }
    util_terminal.toggle_terminal(cmd, opts)
  end
end

return M

